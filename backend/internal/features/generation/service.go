package generation

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"log/slog"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/moderation"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/quota"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider"
)

// Service holds the generation use cases. Each public method is ONE use case
// and returns (result, *apperror.Error) — failures are values the delivery
// layer renders, never panics. The service depends only on the Repository port,
// the provider chain, the moderation checker, and the quota enforcer —
// never on GORM or gin.
type Service struct {
	repo      Repository
	text      *provider.TextChain
	mod       moderation.Checker
	quota     *quota.Service
	log       *slog.Logger
}

// NewService wires the use cases.
func NewService(repo Repository, textChain *provider.TextChain, mod moderation.Checker, quotaSvc *quota.Service, log *slog.Logger) *Service {
	return &Service{
		repo:  repo,
		text:  textChain,
		mod:   mod,
		quota: quotaSvc,
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

	// ── Step 5: Persist GenerationRecord ──────────────────────────────────
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
