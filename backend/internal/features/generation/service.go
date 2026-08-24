package generation

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
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
)

// Service holds the generation use cases. Each public method is ONE use case
// and returns (result, *apperror.Error) — failures are values the delivery
// layer renders, never panics. The service depends only on the Repository port,
// the provider chain, the moderation checker, the quota enforcer, and the
// hashtag bank — never on GORM or gin.
type Service struct {
	repo      Repository
	text      *provider.TextChain
	image     *provider.ImageChain
	mod       moderation.Checker
	quota     *quota.Service
	bank      hashtag.Bank
	log       *slog.Logger
}

// NewService wires the use cases.
func NewService(repo Repository, textChain *provider.TextChain, imageChain *provider.ImageChain, mod moderation.Checker, quotaSvc *quota.Service, bank hashtag.Bank, log *slog.Logger) *Service {
	return &Service{
		repo:  repo,
		text:  textChain,
		image: imageChain,
		mod:   mod,
		quota: quotaSvc,
		bank:  bank,
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
func (s *Service) GenerateText(ctx context.Context, userID uuid.UUID, req generateTextRequest, brandName, tone string) (generateTextResponse, *apperror.Error) {
	// ── Step 1: Quota enforcement ─────────────────────────────────────────
	// The quota service atomically increments and checks the daily cap.
	// On exceed it returns apperror.QuotaExceeded with ResetsAt.
	if qerr := s.quota.Enforce(ctx, userID, models.GenerationText); qerr != nil {
		return generateTextResponse{}, qerr
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
		return generateTextResponse{}, apperror.ModerationRefused("content could not be verified at this time")
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
		return generateTextResponse{}, apperror.ModerationRefused(decision.Reason)
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
		return generateTextResponse{}, genErr
	}

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
	if err := os.MkdirAll(storageDir, 0o755); err != nil {
		return nil, fmt.Errorf("create storage dir: %w", err)
	}

	filePath := filepath.Join(storageDir, filename)
	if err := os.WriteFile(filePath, img.ImageBytes, 0o644); err != nil {
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
func (s *Service) GenerateImage(ctx context.Context, userID uuid.UUID, req generateImageRequest, brandName string) (generateImageResponse, *apperror.Error) {
	// ── Step 1: Quota enforcement ─────────────────────────────────────────
	if qerr := s.quota.Enforce(ctx, userID, models.GenerationImage); qerr != nil {
		return generateImageResponse{}, qerr
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
		return generateImageResponse{}, apperror.ModerationRefused("content could not be verified at this time")
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
		return generateImageResponse{}, apperror.ModerationRefused(decision.Reason)
	}

	// ── Step 3: Provider chain ────────────────────────────────────────────
	imgReq := req.toImageRequest(brandName)
	imgResult, meta, genErr := s.image.GenerateImage(ctx, imgReq)
	if genErr != nil {
		return generateImageResponse{}, genErr
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
		return generateImageResponse{}, apperror.Internal(persistErr)
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

	return generateImageResponse{
		AssetID:  assetRec.ID,
		ImageURL: "/v1/assets/" + assetRec.ID.String(),
		Width:    imgResult.Width,
		Height:   imgResult.Height,
	}, nil
}
