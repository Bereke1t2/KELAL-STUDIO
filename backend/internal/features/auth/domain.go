// Package auth is the reference feature: the fully-worked vertical slice every
// other feature copies. It owns registration, login, refresh-token rotation +
// reuse detection, password reset, and account deletion (PRD §6.1).
//
// Layering within the package mirrors the mobile team's Clean Architecture:
//
//	handler.go / dto.go / routes.go   → delivery (gin only lives here)
//	service.go                        → use cases; returns (T, *apperror.Error)
//	domain.go                         → the Repository PORT + domain types/errors
//	repository.go / repository_mock.go → adapters that implement the port
//	module.go                         → wiring; picks the mock or real adapter
//
// The dependency arrow is delivery → service → Repository (port) ← repository.
// The service depends on the interface declared HERE, never on GORM — so the
// real and mock adapters are interchangeable and the switch is one config flag.
package auth

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// Domain sentinel errors. The repository returns these; the service maps each
// to an *apperror.Error. Keeping them here (not in the adapters) means both the
// GORM and mock adapters agree on the vocabulary the service branches on.
var (
	// ErrEmailTaken is returned by CreateUser when the email already exists.
	ErrEmailTaken = errors.New("auth: email already registered")
	// ErrUserNotFound is returned when no live (non-soft-deleted) user matches.
	ErrUserNotFound = errors.New("auth: user not found")
	// ErrRefreshTokenNotFound is returned when no refresh-token row matches an id.
	ErrRefreshTokenNotFound = errors.New("auth: refresh token not found")
)

// Tokens is the service-layer result of any auth flow that establishes a
// session. The DTO layer maps it to the contract's AuthTokens shape.
type Tokens struct {
	Access  string
	Refresh string
}

// RegisterResult is what registration returns per PRD §11: registration no
// longer establishes a session — it creates the account and (best-effort) sends
// a verification email. VerificationSent reports whether that email was handed
// to the mailer; a false value is not a registration failure (the user can
// resend). The DTO layer maps this to {user_id, verification_sent}.
type RegisterResult struct {
	UserID           string
	VerificationSent bool
}

// Repository is the port the auth service depends on. It is declared here, on
// the CONSUMER side, so the feature never imports a concrete data layer. Two
// adapters implement it: repository.go (GORM/Postgres) and repository_mock.go
// (in-memory). Implementations MUST return the domain sentinel errors above for
// the not-found / duplicate cases — the service relies on errors.Is against them.
type Repository interface {
	// ── Users ──────────────────────────────────────────────────────────────
	// CreateUser persists a new user. It returns ErrEmailTaken if the email is
	// already registered (the unique index is the source of truth, not a
	// prior lookup — that would be a race).
	CreateUser(ctx context.Context, u *models.User) error
	// FindUserByEmail returns the live user with this email, or ErrUserNotFound.
	FindUserByEmail(ctx context.Context, email string) (*models.User, error)
	// FindUserByID returns the live user with this id, or ErrUserNotFound.
	FindUserByID(ctx context.Context, id uuid.UUID) (*models.User, error)
	// UpdateUserPassword sets a new bcrypt hash ONLY if the user's current
	// TokenVersion still equals expectedVersion, and atomically bumps the version
	// (so the reset token that carried expectedVersion can't be replayed). A
	// mismatch — a used token, or a password changed by another route — and a
	// missing/soft-deleted user are indistinguishable: both return ErrUserNotFound,
	// which the service maps to the same opaque failure.
	UpdateUserPassword(ctx context.Context, id uuid.UUID, expectedVersion int, passwordHash string) error
	// MarkEmailVerified stamps email_verified_at (PRD §6.1). It is idempotent —
	// verifying an already-verified account is not an error — and returns
	// ErrUserNotFound only when no live user has this id.
	MarkEmailVerified(ctx context.Context, id uuid.UUID) error
	// SoftDeleteUser marks the account deleted (recoverable, PRD §6.1). Returns
	// ErrUserNotFound if there was nothing live to delete.
	SoftDeleteUser(ctx context.Context, id uuid.UUID) error

	// ── Login lockout (PRD §6.1) ─────────────────────────────────────────────
	// IncrementFailedLoginAttempts bumps the counter and returns the new value,
	// so the service can decide whether the threshold was crossed.
	IncrementFailedLoginAttempts(ctx context.Context, id uuid.UUID) (int, error)
	// LockUser sets locked_until and resets the failed-attempt counter to 0 (the
	// lock itself is now the gate; the counter starts fresh after it lifts).
	LockUser(ctx context.Context, id uuid.UUID, until time.Time) error
	// ResetFailedLoginAttempts clears the counter and any lock — called on a
	// successful login.
	ResetFailedLoginAttempts(ctx context.Context, id uuid.UUID) error

	// ── Refresh tokens (rotation + reuse detection, PRD §6.1) ────────────────
	// CreateRefreshToken persists a new refresh-token row. The caller sets the
	// row's ID up front so it can embed it in the signed token (jti).
	CreateRefreshToken(ctx context.Context, rt *models.RefreshToken) error
	// FindRefreshTokenByID returns the row by id, or ErrRefreshTokenNotFound.
	FindRefreshTokenByID(ctx context.Context, id uuid.UUID) (*models.RefreshToken, error)
	// RevokeRefreshToken marks a single row revoked (used during rotation). It
	// is idempotent: revoking an already-revoked row is not an error.
	RevokeRefreshToken(ctx context.Context, id uuid.UUID) error
	// RevokeAllUserRefreshTokens revokes every live token for a user — used on
	// reuse detection, password change, and account deletion.
	RevokeAllUserRefreshTokens(ctx context.Context, userID uuid.UUID) error
}
