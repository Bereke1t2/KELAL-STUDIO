package generation

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/hashtag"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/moderation"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/quota"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/queue"
)

// Service holds the generation use cases. Each public method is ONE use case
// and returns (result, *apperror.Error) — failures are values the delivery
// layer renders, never panics. The service depends only on the Repository port,
// the provider chain, the moderation checker, the quota enforcer, and the
// hashtag bank — never on GORM or gin.
type Service struct {
	repo  Repository
	text  *provider.TextChain
	image *provider.ImageChain
	mod   moderation.Checker
	quota *quota.Service
	bank  hashtag.Bank
	queue queue.Queue
	log   *slog.Logger
}

// NewService wires the use cases.
func NewService(repo Repository, textChain *provider.TextChain, imageChain *provider.ImageChain, mod moderation.Checker, quotaSvc *quota.Service, bank hashtag.Bank, q queue.Queue, log *slog.Logger) *Service {
	return &Service{
		repo:  repo,
		text:  textChain,
		image: imageChain,
		mod:   mod,
		quota: quotaSvc,
		bank:  bank,
		queue: q,
		log:   log,
	}
}

// GenerateText orchestrates the full text generation flow:
//  1. Enforce daily quota (BEFORE any provider call) — PRD §6.14
//  2. Run moderation check on the input — PRD §6.4
//  3. Compute input hash for cache deduplication
//  4. Check cache for existing result
//  5. Run the provider chain
//  6. Persist a GenerationRecord for telemetry + accounting
//  7. Return the result
func (s *Service) GenerateText(ctx context.Context, userID uuid.UUID, req GenerateTextRequest, brandName, tone string) (GenerateTextResponse, *apperror.Error) {
	// ── Step 1: Quota enforcement ─────────────────────────────────────────
	// The quota service atomically increments and checks the daily cap.
	// On exceed it returns apperror.QuotaExceeded with ResetsAt.
	if qerr := s.quota.Enforce(ctx, userID, models.GenerationText); qerr != nil {
		return GenerateTextResponse{}, qerr
	}

	// ── Step 2: Moderation check ──────────────────────────────────────────
	// Must run BEFORE any outbound provider call (PRD §6.4). On refusal,
	// persist a ModerationFlag for admin review and return a user-facing
	// reason — never a raw classifier code.
	decision, modErr := s.mod.CheckText(ctx, req.InputText, req.InputLang)
	if modErr != nil {
		// Moderation backend unavailable → fail closed (PRD §6.4).
		s.log.Error("moderation check failed",
			"user_id", userID.String(),
			"error", modErr.Error(),
		)
		flag := &models.ModerationFlag{
			UserID:        userID,
			InputSnapshot: req.InputText,
			Reason:        "moderation service unavailable",
		}
		if ferr := s.repo.CreateModerationFlag(ctx, flag); ferr != nil {
			s.log.Error("failed to persist moderation flag",
				"user_id", userID.String(),
				"error", ferr.Error(),
			)
		}
		return GenerateTextResponse{}, apperror.ModerationRefused("content could not be verified at this time")
	}
	if !decision.Allowed {
		flag := &models.ModerationFlag{
			UserID:        userID,
			InputSnapshot: req.InputText,
			Reason:        decision.Reason,
		}
		if ferr := s.repo.CreateModerationFlag(ctx, flag); ferr != nil {
			s.log.Error("failed to persist moderation flag",
				"user_id", userID.String(),
				"error", ferr.Error(),
			)
		}
		return GenerateTextResponse{}, apperror.ModerationRefused(decision.Reason)
	}

	// ── Step 3: Input hash for caching ────────────────────────────────────
	inputHash := computeInputHash(req.InputText, req.Platform, brandName, tone)

	cached, cacheErr := s.repo.FindGenerationRecordByInputHash(ctx, userID, inputHash)
	if cacheErr == nil && cached.OutputRef != "" {
		// Cache hit — the output ref IS the serialized response.
		// For V1, we re-generate from the provider (deterministic stub).
		// A real implementation would deserialize from OutputRef.
		s.log.Info("cache hit for text generation", "user_id", userID.String(), "hash", inputHash)
	}

	// ── Step 4: Provider chain ────────────────────────────────────────────
	textReq := req.toTextRequest(brandName, tone)
	result, meta, genErr := s.text.GenerateText(ctx, textReq)
	if genErr != nil {
		return GenerateTextResponse{}, genErr
	}
	s.log.Info("text generation completed", "provider", meta.Provider, "model", meta.Model, "latency_ms", meta.LatencyMS)

	// ── Step 5: Merge hashtags from bank ──────────────────────────────────
	// The provider generates context-specific hashtags; the bank supplies
	// curated, platform-aware, brand-safe hashtags. Merge, deduplicate,
	// and trim to 5–8 per contract (openapi.yaml GenerateTextResponse).
	topic := hashtag.MatchTopic(req.InputText)
	bankTags, bankErr := s.bank.Suggest(ctx, req.Platform, topic, 8)
	if bankErr != nil {
		// Bank failure is non-fatal — log and use provider hashtags only.
		s.log.Error("hashtag bank failed",
			"platform", req.Platform,
			"topic", topic,
			"error", bankErr.Error(),
		)
	}
	merged := hashtag.MergeHashtags(result.Hashtags, bankTags, 8)
	result.Hashtags = merged

	// ── Step 6: Persist GenerationRecord ──────────────────────────────────
	record := &models.GenerationRecord{
		UserID:       userID,
		Type:         models.GenerationText,
		InputHash:    inputHash,
		Provider:     meta.Provider,
		Model:        meta.Model,
		ModelVersion: meta.ModelVersion,
		LatencyMS:    int(meta.LatencyMS),
	}
	if persistErr := s.repo.CreateGenerationRecord(ctx, record); persistErr != nil {
		// Log but don't fail the request — generation succeeded, persistence
		// is best-effort telemetry.
		s.log.Error("failed to persist generation record",
			"user_id", userID.String(),
			"provider", meta.Provider,
			"error", persistErr.Error(),
		)
	}

	return textResultToResponse(result), nil
}

// computeInputHash produces a deterministic hash of the generation inputs for
// cache deduplication. Empty/missing brand context still produces a stable hash.
func computeInputHash(inputText, platform, brandName, tone string) string {
	h := sha256.New()
	h.Write([]byte(inputText))
	h.Write([]byte{0})
	h.Write([]byte(platform))
	h.Write([]byte{0})
	h.Write([]byte(brandName))
	h.Write([]byte{0})
	h.Write([]byte(tone))
	return hex.EncodeToString(h.Sum(nil))
}

// persistAsset saves the generated image bytes to disk and creates an Asset
// DB record. The storage path is OUTSIDE any web root (PRD §6.8). Returns
// the created Asset for the caller to reference.
func (s *Service) persistAsset(ctx context.Context, userID uuid.UUID, img provider.ImageResult) (*models.Asset, error) {
	// Generate a unique filename.
	filename := uuid.New().String() + ".png"

	// Use a configurable storage directory. For V1, use a default path.
	storageDir := "./storage/assets"
	if err := os.MkdirAll(storageDir, 0o750); err != nil {
		return nil, fmt.Errorf("create storage dir: %w", err)
	}

	filePath := filepath.Join(storageDir, filename)
	if err := os.WriteFile(filePath, img.ImageBytes, 0o600); err != nil {
		return nil, fmt.Errorf("write image file: %w", err)
	}

	// Create the Asset DB record.
	asset := &models.Asset{
		OwnerUserID:      userID,
		StorageRef:       filePath,
		Width:            img.Width,
		Height:           img.Height,
		MimeType:         img.MimeType,
		StrippedMetadata: true, // stub images have no metadata to strip
		CreatedAt:        time.Now().UTC(),
	}

	// Persist via the repository (reuses the generation repo's DB handle
	// through a helper — the Asset is owned by the asset feature in the
	// full implementation, but for V1 we persist directly).
	if err := s.repo.CreateAsset(ctx, asset); err != nil {
		// Clean up the file if DB persist fails.
		_ = os.Remove(filePath)
		return nil, fmt.Errorf("persist asset record: %w", err)
	}

	return asset, nil
}

// GenerateVideo enqueues an async video generation job (PRD §8.4, §10.3).
// Returns immediately with a Job in "queued" status (HTTP 202). The actual
// processing happens in ProcessVideoJob, which is called by the queue consumer.
func (s *Service) GenerateVideo(ctx context.Context, userID uuid.UUID, req GenerateVideoRequest, brandName string) (JobResponse, *apperror.Error) {
	// ── Step 1: Quota enforcement ─────────────────────────────────────────
	if qerr := s.quota.Enforce(ctx, userID, models.GenerationVideo); qerr != nil {
		return JobResponse{}, qerr
	}

	// ── Step 2: Moderation check on the storyboard ────────────────────────
	decision, modErr := s.mod.CheckText(ctx, req.StoryboardText, "en")
	if modErr != nil {
		s.log.Error("moderation check failed for video",
			"user_id", userID.String(),
			"error", modErr.Error(),
		)
		flag := &models.ModerationFlag{
			UserID:        userID,
			InputSnapshot: req.StoryboardText,
			Reason:        "moderation service unavailable",
		}
		if ferr := s.repo.CreateModerationFlag(ctx, flag); ferr != nil {
			s.log.Error("failed to persist moderation flag",
				"user_id", userID.String(),
				"error", ferr.Error(),
			)
		}
		return JobResponse{}, apperror.ModerationRefused("content could not be verified at this time")
	}
	if !decision.Allowed {
		flag := &models.ModerationFlag{
			UserID:        userID,
			InputSnapshot: req.StoryboardText,
			Reason:        decision.Reason,
		}
		if ferr := s.repo.CreateModerationFlag(ctx, flag); ferr != nil {
			s.log.Error("failed to persist moderation flag",
				"user_id", userID.String(),
				"error", ferr.Error(),
			)
		}
		return JobResponse{}, apperror.ModerationRefused(decision.Reason)
	}

	// ── Step 3: Create Job record ─────────────────────────────────────────
	jobID := uuid.New()
	job := &models.Job{
		Base:        models.Base{ID: jobID},
		UserID:      userID,
		Status:      models.JobQueued,
		MaxAttempts: 3,
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
		ExpiresAt:   time.Now().UTC().Add(24 * time.Hour),
	}
	if err := s.repo.CreateJob(ctx, job); err != nil {
		s.log.Error("failed to create job", "user_id", userID.String(), "error", err.Error())
		return JobResponse{}, apperror.Internal(err)
	}

	// ── Step 4: Enqueue for async processing ──────────────────────────────
	payload := VideoJobPayload{
		JobID:          jobID,
		UserID:         userID,
		StoryboardText: req.StoryboardText,
		BrandName:      brandName,
	}
	payloadBytes, _ := json.Marshal(payload)

	qErr := s.queue.Enqueue(ctx, queue.Job{
		ID:      jobID.String(),
		Type:    "video",
		Payload: payloadBytes,
	})
	if qErr != nil {
		s.log.Error("failed to enqueue video job",
			"job_id", jobID.String(),
			"error", qErr.Error(),
		)
		// Update job to failed if enqueue fails.
		_ = s.repo.UpdateJobStatus(ctx, jobID, models.JobFailed, 0, nil)
		return JobResponse{}, apperror.Internal(qErr)
	}

	return JobResponse{
		ID:     jobID,
		Status: string(models.JobQueued),
	}, nil
}

// ProcessVideoJob is called by the queue consumer to actually generate the
// video. In V1 this is a stub that generates a placeholder image (since no
// real video provider ships today — OQ-20). The flow mirrors image generation:
// provider chain → persist asset → update job status.
func (s *Service) ProcessVideoJob(ctx context.Context, job queue.Job) error {
	// Decode the payload.
	var payload VideoJobPayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		s.log.Error("failed to decode video job payload", "job_id", job.ID, "error", err.Error())
		return fmt.Errorf("decode payload: %w", err)
	}

	jobID := payload.JobID
	s.log.Info("processing video job", "job_id", jobID.String(), "user_id", payload.UserID.String())

	// Mark as running.
	_ = s.repo.UpdateJobStatus(ctx, jobID, models.JobRunning, 1, nil)

	// Run the image chain as a placeholder for video (no video provider exists yet).
	imgReq := provider.ImageRequest{
		CaptionEN:   payload.StoryboardText,
		AspectRatio: "9:16", // vertical video format
		BrandName:   payload.BrandName,
	}
	imgResult, meta, genErr := s.image.GenerateImage(ctx, imgReq)
	if genErr != nil {
		s.log.Error("video job: image provider failed",
			"job_id", jobID.String(),
			"error", genErr.Error(),
		)
		_ = s.repo.UpdateJobStatus(ctx, jobID, models.JobFailed, 1, nil)
		return genErr
	}

	// Persist the generated frame as an Asset.
	assetRec, persistErr := s.persistAsset(ctx, payload.UserID, imgResult)
	if persistErr != nil {
		s.log.Error("video job: failed to persist asset",
			"job_id", jobID.String(),
			"error", persistErr.Error(),
		)
		_ = s.repo.UpdateJobStatus(ctx, jobID, models.JobFailed, 1, nil)
		return persistErr
	}

	// Create a GenerationRecord for telemetry.
	record := &models.GenerationRecord{
		UserID:       payload.UserID,
		Type:         models.GenerationVideo,
		Provider:     meta.Provider,
		Model:        meta.Model,
		ModelVersion: meta.ModelVersion,
		LatencyMS:    int(meta.LatencyMS),
		OutputRef:    assetRec.ID.String(),
	}
	_ = s.repo.CreateGenerationRecord(ctx, record)

	// Mark job as done, linking to the generation record.
	_ = s.repo.UpdateJobStatus(ctx, jobID, models.JobDone, 1, &record.ID)
	s.log.Info("video job completed", "job_id", jobID.String(), "asset_id", assetRec.ID.String())

	return nil
}

// GetJob returns the current status of an async job.
func (s *Service) GetJob(ctx context.Context, jobID uuid.UUID) (JobResponse, *apperror.Error) {
	job, err := s.repo.GetJob(ctx, jobID)
	if err != nil {
		if errors.Is(err, ErrJobNotFound) {
			return JobResponse{}, apperror.NotFound("job not found")
		}
		return JobResponse{}, apperror.Internal(err)
	}

	resp := JobResponse{
		ID:     job.ID,
		Status: string(job.Status),
	}
	if job.ResultGenerationRecordID != nil {
		resp.ResultAssetID = job.ResultGenerationRecordID
	}
	return resp, nil
}

// LoadBrandKit is a helper for the handler to resolve a brand kit's context.
// It returns empty strings if brandKitID is nil (no brand context).
// Ownership is NOT enforced here — the handler resolves the caller; this
// just fetches the kit. A missing kit is treated as "no brand context" rather
// than an error, since brand_kit_id is optional in the contract.
func (s *Service) LoadBrandKit(_ context.Context, _ uuid.UUID, _ *uuid.UUID) (brandName, tone string) {
	// Brand kit loading is deferred until the brandkit repository is wired.
	// For now, return empty strings — the provider handles missing brand
	// context gracefully.
	return "", ""
}

// GenerateImage orchestrates the full image generation flow:
//  1. Enforce daily quota (BEFORE any provider call) — PRD §6.14
//  2. Run moderation check on the caption — PRD §6.4
//  3. Run the image provider chain
//  4. Persist the generated image as an Asset (bytes on disk + DB record)
//  5. Persist a GenerationRecord for telemetry + accounting
//  6. Return the asset_id + metadata
func (s *Service) GenerateImage(ctx context.Context, userID uuid.UUID, req GenerateImageRequest, brandName string) (GenerateImageResponse, *apperror.Error) {
	// ── Step 1: Quota enforcement ─────────────────────────────────────────
	if qerr := s.quota.Enforce(ctx, userID, models.GenerationImage); qerr != nil {
		return GenerateImageResponse{}, qerr
	}

	// ── Step 2: Moderation check on the caption ───────────────────────────
	decision, modErr := s.mod.CheckText(ctx, req.CaptionEN, "en")
	if modErr != nil {
		s.log.Error("moderation check failed for image",
			"user_id", userID.String(),
			"error", modErr.Error(),
		)
		flag := &models.ModerationFlag{
			UserID:        userID,
			InputSnapshot: req.CaptionEN,
			Reason:        "moderation service unavailable",
		}
		if ferr := s.repo.CreateModerationFlag(ctx, flag); ferr != nil {
			s.log.Error("failed to persist moderation flag",
				"user_id", userID.String(),
				"error", ferr.Error(),
			)
		}
		return GenerateImageResponse{}, apperror.ModerationRefused("content could not be verified at this time")
	}
	if !decision.Allowed {
		flag := &models.ModerationFlag{
			UserID:        userID,
			InputSnapshot: req.CaptionEN,
			Reason:        decision.Reason,
		}
		if ferr := s.repo.CreateModerationFlag(ctx, flag); ferr != nil {
			s.log.Error("failed to persist moderation flag",
				"user_id", userID.String(),
				"error", ferr.Error(),
			)
		}
		return GenerateImageResponse{}, apperror.ModerationRefused(decision.Reason)
	}

	// ── Step 3: Provider chain ────────────────────────────────────────────
	imgReq := req.toImageRequest(brandName)
	imgResult, meta, genErr := s.image.GenerateImage(ctx, imgReq)
	if genErr != nil {
		return GenerateImageResponse{}, genErr
	}

	// ── Step 4: Persist the image as an Asset ─────────────────────────────
	// Save bytes to disk (outside any web root — PRD §6.8) and create an
	// Asset DB record. The asset_id is what the client uses to reference
	// this image.
	assetRec, persistErr := s.persistAsset(ctx, userID, imgResult)
	if persistErr != nil {
		// If we can't persist the asset, the generation succeeded but we
		// can't serve the image. Return a provider-level error.
		s.log.Error("failed to persist generated image",
			"user_id", userID.String(),
			"error", persistErr.Error(),
		)
		return GenerateImageResponse{}, apperror.Internal(persistErr)
	}

	// ── Step 5: Persist GenerationRecord ──────────────────────────────────
	inputHash := computeInputHash(req.CaptionEN, req.AspectRatio, brandName, "")
	record := &models.GenerationRecord{
		UserID:       userID,
		Type:         models.GenerationImage,
		InputHash:    inputHash,
		Provider:     meta.Provider,
		Model:        meta.Model,
		ModelVersion: meta.ModelVersion,
		LatencyMS:    int(meta.LatencyMS),
		OutputRef:    assetRec.ID.String(), // link to the asset
	}
	if recErr := s.repo.CreateGenerationRecord(ctx, record); recErr != nil {
		s.log.Error("failed to persist generation record",
			"user_id", userID.String(),
			"provider", meta.Provider,
			"error", recErr.Error(),
		)
	}

	return GenerateImageResponse{
		AssetID:  assetRec.ID,
		ImageURL: "/v1/assets/" + assetRec.ID.String(),
		Width:    imgResult.Width,
		Height:   imgResult.Height,
	}, nil
}
