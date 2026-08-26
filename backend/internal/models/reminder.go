package models

import (
	"time"

	"github.com/google/uuid"
)

// ReminderStatus is the lifecycle of a scheduled reminder.
type ReminderStatus string

// Reminder status constants.
const (
	ReminderPending  ReminderStatus = "pending"
	ReminderFired    ReminderStatus = "fired"
	ReminderCanceled ReminderStatus = "canceled"
)

// Reminder stores a "post this later" schedule for a draft (PRD §6.12).
//
// Flags:
//   - draft_local_id is OPAQUE (OQ-05): drafts are device-local in V1, so the
//     backend never dereferences this into a server row.
//   - scheduled_at_utc is ALWAYS UTC; local-time conversion happens only at
//     the mobile presentation layer.
type Reminder struct {
	Base
	UserID         uuid.UUID      `gorm:"type:uuid;index;not null"`
	DraftLocalID   string         `gorm:"not null"` // opaque client string
	ScheduledAtUTC time.Time      `gorm:"index;not null"`
	Status         ReminderStatus `gorm:"type:varchar(16);not null;default:pending;index"`
	FiredAt        *time.Time
	CreatedAt      time.Time
	UpdatedAt      time.Time
}
