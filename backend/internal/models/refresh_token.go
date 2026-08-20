package models

import (
	"time"

	"github.com/google/uuid"
)

// RefreshToken backs refresh-token rotation + reuse detection (PRD §6.1, §10.5).
//
// Only a hash of the token is stored, never the token itself. RotatedFromID
// links each token to the one it replaced, forming a chain; when a token is
// rotated its RevokedAt is set. If a client ever presents a token whose row is
// already revoked, that's reuse of a superseded token — the auth feature treats
// it as compromise and revokes the whole chain (forces re-auth).
type RefreshToken struct {
	Base
	UserID        uuid.UUID  `gorm:"type:uuid;index;not null"`
	TokenHash     string     `gorm:"uniqueIndex;not null"`
	RotatedFromID *uuid.UUID `gorm:"type:uuid;index"`
	ExpiresAt     time.Time  `gorm:"not null"`
	RevokedAt     *time.Time
	CreatedAt     time.Time
}
