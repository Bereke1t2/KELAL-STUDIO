// Package quota owns the quota read endpoint (GET /quota/me, PRD §6.14) AND the
// far more important pre-call ENFORCEMENT: before any billable generation, the
// per-user daily cap must be checked and the consumption recorded
// (models.QuotaConsumption).
//
// Non-negotiable rules (PRD §6.14, §12):
//   - Enforcement MUST happen BEFORE any outbound provider call.
//   - On exceed it returns apperror.QuotaExceeded carrying ResetsAt (the
//     contract's only 429-with-reset case).
//   - The (UserID, Period) pair is unique — one row per user per day.
package quota

import (
	"context"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// Repository is the port the quota service depends on. Two adapters implement
// it: repository.go (GORM/Postgres) and repository_mock.go (in-memory).
type Repository interface {
	// UpsertAndCheck atomically increments the call count for the given user
	// and generation type on today's period, then returns whether the daily cap
	// has been reached (or exceeded). If no row exists for today it creates one.
	// The returned ResetsAt is midnight UTC of the next day.
	UpsertAndCheck(ctx context.Context, userID uuid.UUID, genType models.GenerationType) (exceeded bool, resetsAt interface{}, err error)

	// GetTodayUsage returns the current day's call counts for a user.
	GetTodayUsage(ctx context.Context, userID uuid.UUID) (textUsed, imageUsed int, err error)
}

// QuotaLimits holds the per-user daily caps read from config.
type QuotaLimits struct {
	TextDaily  int
	ImageDaily int
}

// UsageResponse is the wire shape for GET /quota/me (openapi.yaml).
type UsageResponse struct {
	TextUsed  int `json:"text_used"`
	TextCap   int `json:"text_cap"`
	ImageUsed int `json:"image_used"`
	ImageCap  int `json:"image_cap"`
}
