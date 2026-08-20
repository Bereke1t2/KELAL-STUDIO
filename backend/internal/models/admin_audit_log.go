package models

import (
	"time"

	"github.com/google/uuid"
)

// AdminAuditLog is an append-only record of privileged actions (PRD §6.13,
// §10.5). Every admin endpoint writes one — reviewing a flag, changing a user's
// limits — so admin activity is fully traceable. TargetRef identifies the
// affected entity (e.g. "user:<id>", "flag:<id>").
type AdminAuditLog struct {
	Base
	AdminUserID uuid.UUID `gorm:"type:uuid;index;not null"`
	Action      string    `gorm:"not null"`
	TargetRef   string
	CreatedAt   time.Time
}
