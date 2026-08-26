package quota

import (
	"context"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// gormRepository is the real Repository adapter over Postgres.
type gormRepository struct {
	db *gorm.DB
}

// NewGormRepository builds the Postgres-backed quota repository.
func NewGormRepository(db *gorm.DB) Repository {
	return &gormRepository{db: db}
}

func (r *gormRepository) UpsertAndCheck(ctx context.Context, userID uuid.UUID, genType models.GenerationType) (bool, interface{}, error) {
	period := time.Now().UTC().Format("2006-01-02")
	midnight := time.Now().UTC().Truncate(24 * time.Hour).Add(24 * time.Hour)

	// Upsert: create or find today's row, then atomically increment the
	// relevant counter. GORM's Claire OnConflict handles the Postgres
	// ON CONFLICT DO UPDATE path.
	rec := models.QuotaConsumption{
		UserID: userID,
		Period: period,
	}

	// Build the increment map based on generation type.
	updates := map[string]interface{}{
		"text_calls_used":  gorm.Expr("quota_consumptions.text_calls_used + 1"),
		"image_calls_used": gorm.Expr("quota_consumptions.image_calls_used + 1"),
		"updated_at":       time.Now().UTC(),
	}

	// We only increment the relevant counter; set the other to 0 via COALESCE
	// so it doesn't double-count. Actually simpler: only increment the one
	// that matters.
	switch genType {
	case models.GenerationText:
		updates = map[string]interface{}{
			"text_calls_used": gorm.Expr("COALESCE(quota_consumptions.text_calls_used, 0) + 1"),
			"updated_at":      time.Now().UTC(),
		}
	case models.GenerationImage:
		updates = map[string]interface{}{
			"image_calls_used": gorm.Expr("COALESCE(quota_consumptions.image_calls_used, 0) + 1"),
			"updated_at":       time.Now().UTC(),
		}
	}

	result := r.db.WithContext(ctx).
		Clauses(clause.OnConflict{
			Columns:   []clause.Column{{Name: "user_id"}, {Name: "period"}},
			DoUpdates: clause.Assignments(updates),
		}).
		Create(&rec).Error
	if result != nil {
		return false, midnight, result
	}

	// Re-read to get the post-increment counts.
	var updated models.QuotaConsumption
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND period = ?", userID, period).
		First(&updated).Error
	if err != nil {
		return false, midnight, err
	}

	return false, midnight, nil
}

func (r *gormRepository) GetTodayUsage(ctx context.Context, userID uuid.UUID) (int, int, error) {
	period := time.Now().UTC().Format("2006-01-02")

	var rec models.QuotaConsumption
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND period = ?", userID, period).
		First(&rec).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return 0, 0, nil
		}
		return 0, 0, err
	}
	return rec.TextCallsUsed, rec.ImageCallsUsed, nil
}
