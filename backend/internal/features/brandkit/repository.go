package brandkit

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// gormRepository is the real Repository adapter over Postgres. It translates
// GORM's errors into the feature's domain sentinels so the service never sees a
// driver-specific error. GORM is configured with TranslateError (see
// platform/database), so duplicate keys surface as gorm.ErrDuplicatedKey and
// missing rows as gorm.ErrRecordNotFound.
type gormRepository struct {
	db *gorm.DB
}

// NewGormRepository builds the Postgres-backed brand-kit repository.
func NewGormRepository(db *gorm.DB) Repository {
	return &gormRepository{db: db}
}

func (r *gormRepository) FindByID(ctx context.Context, id uuid.UUID) (*models.BrandKit, error) {
	var kit models.BrandKit
	if err := r.db.WithContext(ctx).First(&kit, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrBrandKitNotFound
		}
		return nil, err
	}
	return &kit, nil
}

func (r *gormRepository) Create(ctx context.Context, kit *models.BrandKit) error {
	if err := r.db.WithContext(ctx).Create(kit).Error; err != nil {
		if errors.Is(err, gorm.ErrDuplicatedKey) {
			return ErrBrandKitExists
		}
		return err
	}
	return nil
}

func (r *gormRepository) Update(ctx context.Context, kit *models.BrandKit) error {
	// Save writes every column (a full PUT replace) and lets GORM bump
	// updated_at. The service only calls Update after a successful FindByID, so
	// the row exists; the RowsAffected guard stays honest if it raced away.
	res := r.db.WithContext(ctx).Save(kit)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrBrandKitNotFound
	}
	return nil
}
