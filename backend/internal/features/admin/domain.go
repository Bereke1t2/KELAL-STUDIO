// Package admin owns the admin portal API (PRD §6.13): aggregate usage
// analytics, the moderation-flag review queue, flag review, and per-user limit
// overrides. It is BACKEND-ONLY — the admin surface is a future web portal, not
// part of the mobile contract — and every route is gated by BOTH authentication
// and the admin role (mw.AuthRequired + mw.AdminOnly, applied in routes.go).
//
// It is built by copying the auth/brandkit reference layout:
//
//	handler.go / dto.go / routes.go    → delivery (gin only lives here)
//	service.go                         → use cases; returns (T, *apperror.Error)
//	domain.go                          → the Repository PORT + domain types/errors
//	repository.go / repository_mock.go → adapters that implement the port
//	module.go                          → wiring; picks the mock or real adapter
//
// Admin is a cross-cutting READER: usage counts and the flag queue aggregate
// rows conceptually owned by other features (users, generation_records,
// moderation_flags). It reaches them only through the shared models package and
// its own Repository port — never by importing another feature — so the
// "features never import each other" rule holds.
//
// The load-bearing invariant (PRD §6.13, §10.5): every STATE-CHANGING admin
// action writes an append-only models.AdminAuditLog row (who, what, when,
// target). That is enforced structurally here — the mutating port methods
// (ReviewFlag, SetUserLimits) TAKE the audit row as a required argument and
// persist it in the SAME transaction as the mutation, so an admin write can
// never land without its audit trail.
package admin

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// Domain sentinel errors. The repository returns these; the service maps each to
// an *apperror.Error. Declaring them here (not in the adapters) keeps the GORM
// and mock adapters agreeing on the vocabulary the service branches on with
// errors.Is — exactly as the auth/brandkit features do.
var (
	// ErrFlagNotFound is returned when no moderation flag matches an id.
	ErrFlagNotFound = errors.New("admin: moderation flag not found")
	// ErrFlagAlreadyReviewed is returned when a review is attempted on a flag
	// another request already adjudicated. It is the atomic backstop for the
	// single-reviewer (409) invariant: the service pre-checks, but two admins can
	// race past that check, so the repository claims the flag conditionally and
	// returns this when it loses the race.
	ErrFlagAlreadyReviewed = errors.New("admin: moderation flag already reviewed")
	// ErrUserNotFound is returned when no user matches an id.
	ErrUserNotFound = errors.New("admin: user not found")
)

// UsageSummary is the aggregate analytics payload behind GET /admin/usage. The
// counts are whole-population totals — V1 analytics is intentionally coarse (no
// time-bucketing yet). Against Postgres they aggregate the live tables; in mock
// mode they reflect only what the in-memory repo was seeded with, since each
// feature's mock is isolated (there is no shared in-memory database).
type UsageSummary struct {
	TotalUsers       int64
	TotalGenerations int64
	TextGenerations  int64
	ImageGenerations int64
	VideoGenerations int64
	TotalFlags       int64
	PendingFlags     int64
}

// LimitsInput carries the per-user quota overrides for SetUserLimits. Each field
// is a pointer so nil is meaningful: "clear the override, fall back to the global
// default" — distinct from a zero value ("cap at zero"). It is a domain type (no
// json tags) so the service never depends on the delivery DTO.
type LimitsInput struct {
	DailyTextQuota  *int
	DailyImageQuota *int
}

// Repository is the port the admin service depends on, declared here on the
// CONSUMER side so the feature never imports a concrete data layer. Two adapters
// implement it: repository.go (GORM/Postgres) and repository_mock.go (in-memory).
//
// The two MUTATING methods (ReviewFlag, SetUserLimits) take a fully-populated
// *models.AdminAuditLog and MUST persist it atomically with the mutation — the
// PRD's "no silent admin action" rule made structural: they cannot be called
// without supplying the audit row.
type Repository interface {
	// UsageSummary returns the aggregate usage counts (GET /admin/usage).
	UsageSummary(ctx context.Context) (UsageSummary, error)

	// ListFlags returns moderation flags newest-first. When onlyPending is true it
	// returns only flags not yet reviewed (ReviewedAt IS NULL).
	ListFlags(ctx context.Context, onlyPending bool) ([]models.ModerationFlag, error)
	// FindFlagByID returns the flag with this id, or ErrFlagNotFound.
	FindFlagByID(ctx context.Context, id uuid.UUID) (*models.ModerationFlag, error)
	// ReviewFlag persists the (already-mutated) flag and the audit row in one
	// transaction, but ONLY while the flag is still unreviewed — it is a
	// conditional claim (reviewed_at IS NULL), so two admins racing past the
	// service pre-check can't both win. Returns ErrFlagAlreadyReviewed if another
	// request already adjudicated it, or ErrFlagNotFound if the row vanished.
	ReviewFlag(ctx context.Context, flag *models.ModerationFlag, audit *models.AdminAuditLog) error

	// FindUserByID returns the user with this id, or ErrUserNotFound.
	FindUserByID(ctx context.Context, id uuid.UUID) (*models.User, error)
	// SetUserLimits persists the (already-mutated) user and the audit row in one
	// transaction, returning ErrUserNotFound if the row vanished under it.
	SetUserLimits(ctx context.Context, user *models.User, audit *models.AdminAuditLog) error
}
