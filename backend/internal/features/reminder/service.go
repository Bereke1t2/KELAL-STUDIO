package reminder

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
)

// Service holds the reminder use cases.
type Service struct {
	repo Repository
	log  *slog.Logger
}

func NewService(repo Repository, log *slog.Logger) *Service {
	return &Service{repo: repo, log: log}
}

// CreateReminderRequest is the validated input for creating a reminder.
type CreateReminderRequest struct {
	DraftLocalID   string
	ScheduledAtUTC time.Time
}

// CreateReminderResponse is the wire shape for POST /reminders (201).
type CreateReminderResponse struct {
	ID             uuid.UUID `json:"id"`
	DraftLocalID   string    `json:"draft_local_id"`
	ScheduledAtUTC time.Time `json:"scheduled_at_utc"`
	Status         string    `json:"status"`
}

// CreateReminder validates and persists a new scheduled reminder (PRD §6.12).
func (s *Service) CreateReminder(ctx context.Context, userID uuid.UUID, req CreateReminderRequest) (CreateReminderResponse, *apperror.Error) {
	// Validate scheduled_at_utc is in the future.
	if req.ScheduledAtUTC.Before(time.Now().UTC()) {
		return CreateReminderResponse{}, apperror.Validation("scheduled_at_utc must be in the future")
	}

	// Validate it's not too far out (max 30 days).
	maxFuture := time.Now().UTC().Add(30 * 24 * time.Hour)
	if req.ScheduledAtUTC.After(maxFuture) {
		return CreateReminderResponse{}, apperror.Validation("scheduled_at_utc cannot be more than 30 days in the future")
	}

	reminder := &models.Reminder{
		UserID:         userID,
		DraftLocalID:   req.DraftLocalID,
		ScheduledAtUTC: req.ScheduledAtUTC,
		Status:         models.ReminderPending,
		CreatedAt:      time.Now().UTC(),
		UpdatedAt:      time.Now().UTC(),
	}

	if err := s.repo.CreateReminder(ctx, reminder); err != nil {
		s.log.Error("failed to create reminder",
			"user_id", userID.String(),
			"error", err.Error(),
		)
		return CreateReminderResponse{}, apperror.Internal(err)
	}

	return CreateReminderResponse{
		ID:             reminder.ID,
		DraftLocalID:   reminder.DraftLocalID,
		ScheduledAtUTC: reminder.ScheduledAtUTC,
		Status:         string(reminder.Status),
	}, nil
}

// FireDueReminders finds all pending reminders whose scheduled time has passed
// and "fires" them. In V1 this logs the notification — a real implementation
// would dispatch push notifications via FCM/SNS/etc.
//
// This is called by the background scheduler at a regular interval (e.g. every
// minute).
func (s *Service) FireDueReminders(ctx context.Context) {
	due, err := s.repo.FindDueReminders(ctx, 50)
	if err != nil {
		s.log.Error("failed to find due reminders", "error", err.Error())
		return
	}

	now := time.Now().UTC()
	for _, r := range due {
		// Mark as fired.
		if err := s.repo.UpdateReminderStatus(ctx, r.ID, models.ReminderFired, &now); err != nil {
			s.log.Error("failed to fire reminder",
				"reminder_id", r.ID.String(),
				"user_id", r.UserID.String(),
				"error", err.Error(),
			)
			continue
		}

		// V1: log the notification. A real implementation would dispatch
		// a push notification to the user's device telling them to open
		// the app and post their draft.
		s.log.Info("reminder fired",
			"reminder_id", r.ID.String(),
			"user_id", r.UserID.String(),
			"draft_local_id", r.DraftLocalID,
			"scheduled_at", r.ScheduledAtUTC.Format(time.RFC3339),
			"fired_at", now.Format(time.RFC3339),
			"action", fmt.Sprintf("notify user to post draft %s", r.DraftLocalID),
		)
	}

	if len(due) > 0 {
		s.log.Info("processed due reminders", "count", len(due))
	}
}
