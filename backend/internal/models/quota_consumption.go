package models

import (
	"time"

	"github.com/google/uuid"
)

// QuotaConsumption is one user's usage for one day (PRD §6.14, §10.5). The
// (UserID, Period) pair is unique — one row per user per day — so the quota
// feature can enforce the daily cap with a single upsert-and-check BEFORE any
// outbound provider call. Period is a calendar day "YYYY-MM-DD".
//
// NOTE: the day boundary depends on which timezone the cap resets in — the PRD
// doesn't pin one. Treated as UTC here; flagged in docs/OPEN_QUESTIONS.md.
type QuotaConsumption struct {
	Base
	UserID         uuid.UUID `gorm:"type:uuid;not null;uniqueIndex:idx_quota_user_period"`
	Period         string    `gorm:"type:varchar(10);not null;uniqueIndex:idx_quota_user_period"`
	TextCallsUsed  int
	ImageCallsUsed int
	CapReachedAt   *time.Time
	CreatedAt      time.Time
	UpdatedAt      time.Time
}
