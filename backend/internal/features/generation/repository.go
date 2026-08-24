package generation

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// gormRepository is the real Repository adapter over Postgres.
type gormRepository struct {
	db *gorm.DB
}

// NewGormRepository builds the Postgres-backed generation repository.
func NewGormRepository(db *gorm.DB) Repository {
	return &gormRepository{db: db}
}

func (r *gormRepository) CreateGenerationRecord(ctx context.Context, rec *models.GenerationRecord) error {
	return r.db.WithContext(ctx).Create(rec).Error
}

func (r *gormRepository) FindGenerationRecordByInputHash(ctx context.Context, userID uuid.UUID, inputHash string) (*models.GenerationRecord, error) {
	var rec models.GenerationRecord
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND input_hash = ? AND input_hash != ''", userID, inputHash).
		Order("created_at DESC").
		First(&rec).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrGenerationRecordNotFound
		}
		return nil, err
	}
	return &rec, nil
}

func (r *gormRepository) CountTodayGenerations(ctx context.Context, userID uuid.UUID, genType models.GenerationType) (int64, error) {
	today := time.Now().UTC().Truncate(24 * time.Hour)
	var count int64
	err := r.db.WithContext(ctx).
		Model(&models.GenerationRecord{}).
		Where("user_id = ? AND type = ? AND created_at >= ?", userID, genType, today).
		Count(&count).Error
	return count, err
}

func (r *gormRepository) CreateModerationFlag(ctx context.Context, rec *models.ModerationFlag) error {
	return r.db.WithContext(ctx).Create(rec).Error
}

func (r *gormRepository) CreateAsset(ctx context.Context, rec *models.Asset) error {
	return r.db.WithContext(ctx).Create(rec).Error
}

func (r *gormRepository) CreateJob(ctx context.Context, rec *models.Job) error {
	return r.db.WithContext(ctx).Create(rec).Error
}

func (r *gormRepository) GetJob(ctx context.Context, id uuid.UUID) (*models.Job, error) {
	var rec models.Job
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&rec).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrJobNotFound
		}
		return nil, err
	}
	return &rec, nil
}

func (r *gormRepository) UpdateJobStatus(ctx context.Context, id uuid.UUID, status models.JobStatus, attempts int, resultID *uuid.UUID) error {
	updates := map[string]interface{}{
		"status":   status,
		"attempts": attempts,
		"updated_at": time.Now().UTC(),
	}
	if resultID != nil {
		updates["result_generation_record_id"] = *resultID
	}
	return r.db.WithContext(ctx).Model(&models.Job{}).Where("id = ?", id).Updates(updates).Error
}
