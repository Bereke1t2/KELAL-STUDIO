// Package reminder owns scheduling a "post this later" reminder for a draft
// (POST /reminders, PRD §6.12).
//
// Non-negotiable rules:
//   - Times are ALWAYS UTC on the wire (scheduled_at_utc); local-time
//     conversion happens only at the mobile presentation layer. Store UTC,
//     never a local time or a floating wall-clock (PRD §6.12).
//   - OQ-05: drafts are device-local in V1 — there is NO drafts table and NO
//     /drafts endpoint. draft_local_id is an OPAQUE client string the backend
//     stores and echoes back; it must NOT be treated as a server FK.
package reminder

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

var (
	// ErrReminderNotFound is returned when no reminder matches a query.
	ErrReminderNotFound = errors.New("reminder: not found")
)

// Repository is the port the reminder service depends on. Two adapters
// implement it: repository.go (GORM/Postgres) and repository_mock.go
// (in-memory).
type Repository interface {
	// CreateReminder persists a new scheduled reminder.
	CreateReminder(ctx context.Context, r *models.Reminder) error
	// GetReminder returns a reminder by ID, or ErrReminderNotFound.
	GetReminder(ctx context.Context, id uuid.UUID) (*models.Reminder, error)
	// FindDueReminders returns all pending reminders whose scheduled time
	// has passed (ready to fire), up to the given limit.
	FindDueReminders(ctx context.Context, limit int) ([]models.Reminder, error)
	// UpdateReminderStatus updates the status and optionally the fired_at time.
	UpdateReminderStatus(ctx context.Context, id uuid.UUID, status models.ReminderStatus, firedAt *time.Time) error
}
