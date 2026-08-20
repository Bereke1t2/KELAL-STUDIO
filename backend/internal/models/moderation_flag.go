package models

import (
	"time"

	"github.com/google/uuid"
)

// ModerationFlag records a moderation refusal for admin review (PRD §6.4, §6.13,
// §10.5). InputSnapshot captures what tripped the filter; Reason is a
// plain-language explanation (never a raw classifier code). Reviewed* are set
// when an admin adjudicates it.
type ModerationFlag struct {
	Base
	UserID            uuid.UUID `gorm:"type:uuid;index;not null"`
	InputSnapshot     string    `gorm:"type:text"`
	Reason            string
	ReviewedByAdminID *uuid.UUID `gorm:"type:uuid"`
	ReviewedAt        *time.Time
	CreatedAt         time.Time
}
