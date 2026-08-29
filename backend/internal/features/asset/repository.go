package asset

import (
	"context"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// gormRepository is the real Repository adapter over Postgres. Asset rows are
// insert-only through this feature, so it exposes just Create.
type gormRepository struct {
	db *gorm.DB
}

// NewGormRepository builds the Postgres-backed asset repository.
func NewGormRepository(db *gorm.DB) Repository {
	return &gormRepository{db: db}
}

func (r *gormRepository) Create(ctx context.Context, a *models.Asset) error {
	return r.db.WithContext(ctx).Create(a).Error
}

func (r *gormRepository) FindByID(ctx context.Context, id uuid.UUID) (*models.Asset, error) {
	var a models.Asset
	if err := r.db.WithContext(ctx).First(&a, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return &a, nil
}
