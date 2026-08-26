package models

import (
	"time"

	"gorm.io/gorm"
)

// Role mirrors the string values in platform/auth (RoleUser/RoleAdmin) so the
// value that lands in a JWT and the value stored in the DB are the same tokens.
type Role string

// RoleUser and RoleAdmin are the account roles carried in the JWT and stored in
// the DB.
const (
	RoleUser  Role = "user"
	RoleAdmin Role = "admin"
)

// User is an account (PRD §10.5). Password is stored only as a bcrypt hash.
// Soft-deleted (DeletedAt) so account deletion (PRD §6.1 DELETE /account) is
// recoverable/auditable rather than a hard wipe.
type User struct {
	Base
	Email        string `gorm:"uniqueIndex;not null"`
	PasswordHash string `gorm:"not null"`
	// EmailVerifiedAt is nil until the user verifies via POST /auth/verify-email.
	// Verification gates content generation (PRD §6.1) — the auth service reads
	// this to set the email_verified access-token claim the gate checks.
	EmailVerifiedAt *time.Time
	Role            Role `gorm:"type:varchar(16);not null"`
	// TokenVersion makes a password-reset token single-use (PRD §6.1). It is
	// embedded in each reset token and bumped on every password change, so a used
	// token — or any password change by another route — invalidates outstanding
	// reset tokens. It is NOT an access-token security stamp; those are bounded by
	// their short TTL, not by this counter.
	TokenVersion int `gorm:"not null;default:0"`
	// FailedLoginAttempts / LockedUntil back the account-lockout policy (PRD §6.1):
	// the counter increments on each wrong password and resets to 0 on success or
	// when a lock is applied; LockedUntil is when a temporary lock lifts (nil = not
	// locked).
	FailedLoginAttempts int `gorm:"not null;default:0"`
	LockedUntil         *time.Time
	// DailyTextQuota / DailyImageQuota are per-user overrides of the global daily
	// generation caps (config.QuotaConfig.TextDaily / ImageDaily), set by an admin
	// via PUT /admin/users/{id}/limits (PRD §6.13). nil means "no override — use
	// the global default"; 0 is a real value (block all generation of that kind).
	// The quota enforcer (PRD §6.14) reads these when it's built. Kept nullable so
	// "unset" is distinct from "capped at zero". See docs/OPEN_QUESTIONS.md →
	// admin-user-limits.
	DailyTextQuota  *int
	DailyImageQuota *int
	CreatedAt       time.Time
	UpdatedAt       time.Time
	DeletedAt       gorm.DeletedAt `gorm:"index"`
}
