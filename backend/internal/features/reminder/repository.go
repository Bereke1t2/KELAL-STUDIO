package reminder

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

type gormRepository struct {
	db *gorm.DB
}

// NewGormRepository builds a Postgres-backed reminder repository.
func NewGormRepository(db *gorm.DB) Repository {
	return &gormRepository{db: db}
}

func (r *gormRepository) CreateReminder(ctx context.Context, rec *models.Reminder) error {
	return r.db.WithContext(ctx).Create(rec).Error
}

func (r *gormRepository) GetReminder(ctx context.Context, id uuid.UUID) (*models.Reminder, error) {
	var rec models.Reminder
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&rec).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrReminderNotFound
		}
		return nil, err
	}
	return &rec, nil
}

func (r *gormRepository) FindDueReminders(ctx context.Context, limit int) ([]models.Reminder, error) {
	var recs []models.Reminder
	err := r.db.WithContext(ctx).
		Where("status = ? AND scheduled_at_utc <= ?", models.ReminderPending, time.Now().UTC()).
		Order("scheduled_at_utc ASC").
		Limit(limit).
		Find(&recs).Error
	return recs, err
}

func (r *gormRepository) UpdateReminderStatus(ctx context.Context, id uuid.UUID, status models.ReminderStatus, firedAt *time.Time) error {
	updates := map[string]interface{}{
		"status":     status,
		"updated_at": time.Now().UTC(),
	}
	if firedAt != nil {
		updates["fired_at"] = *firedAt
	}
	return r.db.WithContext(ctx).Model(&models.Reminder{}).Where("id = ?", id).Updates(updates).Error
}
