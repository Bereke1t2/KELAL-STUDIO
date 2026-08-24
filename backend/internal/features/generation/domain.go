// Package generation owns AI content generation: text (PRD §6.2, §6.3), image
// (§6.5), and video (§6.5, §8.4), plus job status (§10.3).
//
// Layering within the package mirrors the auth reference feature:
//
//	handler.go / dto.go / routes.go   → delivery (gin only lives here)
//	service.go                        → use cases; returns (T, *apperror.Error)
//	domain.go                         → the Repository PORT + domain types/errors
//	repository.go / repository_mock.go → adapters that implement the port
//	module.go                         → wiring; picks the mock or real adapter
//
// Non-negotiable rules when this is built (see docs/ARCHITECTURE.md):
//   - NEVER call an AI provider directly. Every generation goes through
//     platform/provider (the failover chain), so a provider swap is config-only
//     and no API key ever leaves the server (PRD §1.1, §10.1, §7.8).
//   - Run the moderation check (internal moderation feature) and enforce quota
//     (quota feature) BEFORE any outbound provider call (PRD §6.4, §6.14).
//   - Persist a models.GenerationRecord per call (provider, model, cost,
//     latency) for telemetry and quota accounting.
package generation

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// Domain sentinel errors. The repository returns these; the service maps each
// to an *apperror.Error.
var (
	// ErrGenerationRecordNotFound is returned when no record matches a query.
	ErrGenerationRecordNotFound = errors.New("generation: record not found")
)

// Repository is the port the generation service depends on, declared here on
// the CONSUMER side so the feature never imports a concrete data layer. Two
// adapters implement it: repository.go (GORM/Postgres) and repository_mock.go
// (in-memory).
type Repository interface {
	// CreateGenerationRecord persists a new generation audit row.
	CreateGenerationRecord(ctx context.Context, r *models.GenerationRecord) error
	// FindGenerationRecordByInputHash returns an existing record for cache
	// deduplication, or ErrGenerationRecordNotFound if none exists.
	FindGenerationRecordByInputHash(ctx context.Context, userID uuid.UUID, inputSnapshot string) (*models.GenerationRecord, error)
	// CountTodayGenerations returns how many generations of the given type the
	// user has performed since midnight UTC today.
	CountTodayGenerations(ctx context.Context, userID uuid.UUID, genType models.GenerationType) (int64, error)
	// CreateModerationFlag persists a moderation refusal for admin review
	// (PRD §6.4, §6.13). Returns the generated flag ID so the caller can
	// link it to a GenerationRecord if needed.
	CreateModerationFlag(ctx context.Context, r *models.ModerationFlag) error
	// CreateAsset persists a generated image/file as an Asset (PRD §6.8).
	// The asset's StorageRef points at bytes saved outside any web root.
	CreateAsset(ctx context.Context, r *models.Asset) error
}
