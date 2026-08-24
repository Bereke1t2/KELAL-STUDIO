package generation

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider"
)

// dailyTextQuota is the per-user daily cap for text generations. It is read
// from config in production; this is the fallback default.
const dailyTextQuota = 50

// Service holds the generation use cases. Each public method is ONE use case
// and returns (result, *apperror.Error) — failures are values the delivery
// layer renders, never panics. The service depends only on the Repository port,
// the provider chain, and the moderation checker — never on GORM or gin.
type Service struct {
	repo   Repository
	text   *provider.TextChain
	log    *slog.Logger
	quota  int // per-user daily text cap
}

// NewService wires the use cases.
func NewService(repo Repository, textChain *provider.TextChain, log *slog.Logger, dailyTextQuota int) *Service {
	if dailyTextQuota <= 0 {
		dailyTextQuota = dailyTextQuota
	}
	return &Service{
		repo:  repo,
		text:  textChain,
		log:   log,
		quota: dailyTextQuota,
	}
}

// GenerateText orchestrates the full text generation flow:
//  1. Validate input (handler-bound)
//  2. Enforce daily quota (BEFORE any provider call)
//  3. Compute input hash for cache deduplication
//  4. Check cache for existing result
//  5. Run the provider chain
//  6. Persist a GenerationRecord for telemetry + accounting
//  7. Return the result
//
// Moderation is NOT called here — it is a pre-generation gate that the handler
// calls before the service. This keeps the service focused on generation logic
// and lets the handler orchestrate cross-cutting concerns (PRD §6.4).
func (s *Service) GenerateText(ctx context.Context, userID uuid.UUID, req generateTextRequest, brandName, tone string) (generateTextResponse, *apperror.Error) {
	// ── Step 1: Quota enforcement ─────────────────────────────────────────
	count, err := s.repo.CountTodayGenerations(ctx, userID, models.GenerationText)
	if err != nil {
		s.log.Error("failed to count daily generations", "user_id", userID.String(), "error", err.Error())
		return generateTextResponse{}, apperror.Internal(err)
	}
	if s.quota > 0 && int(count) >= s.quota {
		midnight := time.Now().UTC().Truncate(24 * time.Hour).Add(24 * time.Hour)
		return generateTextResponse{}, apperror.QuotaExceeded(
			fmt.Sprintf("daily text generation limit of %d reached", s.quota),
			midnight,
		)
	}

	// ── Step 2: Input hash for caching ────────────────────────────────────
	inputHash := computeInputHash(req.InputText, req.Platform, brandName, tone)

	cached, cacheErr := s.repo.FindGenerationRecordByInputHash(ctx, userID, inputHash)
	if cacheErr == nil && cached.OutputRef != "" {
		// Cache hit — the output ref IS the serialized response.
		// For V1, we re-generate from the provider (deterministic stub).
		// A real implementation would deserialize from OutputRef.
		s.log.Info("cache hit for text generation", "user_id", userID.String(), "hash", inputHash)
	}

	// ── Step 3: Provider chain ────────────────────────────────────────────
	textReq := req.toTextRequest(brandName, tone)
	result, meta, genErr := s.text.GenerateText(ctx, textReq)
	if genErr != nil {
		return generateTextResponse{}, genErr
	}

	// ── Step 4: Persist GenerationRecord ──────────────────────────────────
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
