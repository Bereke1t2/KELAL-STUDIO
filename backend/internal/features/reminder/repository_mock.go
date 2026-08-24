package reminder

import (
	"context"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

type mockRepository struct {
	mu        sync.RWMutex
	reminders []models.Reminder
}

func NewMockRepository() Repository {
	return &mockRepository{}
}

func (m *mockRepository) CreateReminder(_ context.Context, r *models.Reminder) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if r.ID == uuid.Nil {
		r.ID = uuid.New()
	}
	if r.CreatedAt.IsZero() {
		r.CreatedAt = time.Now()
	}
	if r.Status == "" {
		r.Status = models.ReminderPending
	}
	m.reminders = append(m.reminders, *r)
	return nil
}

func (m *mockRepository) GetReminder(_ context.Context, id uuid.UUID) (*models.Reminder, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	for i := range m.reminders {
		if m.reminders[i].ID == id {
			copy := m.reminders[i]
			return &copy, nil
		}
	}
	return nil, ErrReminderNotFound
}

func (m *mockRepository) FindDueReminders(_ context.Context, limit int) ([]models.Reminder, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	now := time.Now().UTC()
	var result []models.Reminder
	for _, r := range m.reminders {
		if r.Status == models.ReminderPending && !r.ScheduledAtUTC.After(now) {
			result = append(result, r)
			if len(result) >= limit {
				break
			}
		}
	}
	return result, nil
}

func (m *mockRepository) UpdateReminderStatus(_ context.Context, id uuid.UUID, status models.ReminderStatus, firedAt *time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for i := range m.reminders {
		if m.reminders[i].ID == id {
			m.reminders[i].Status = status
			m.reminders[i].UpdatedAt = time.Now()
			if firedAt != nil {
				m.reminders[i].FiredAt = firedAt
			}
			return nil
		}
	}
	return ErrReminderNotFound
}
