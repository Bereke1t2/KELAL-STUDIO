package admin

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// gormRepository is the real Repository adapter over Postgres. Admin aggregates
// and mutates rows across several tables (users, generation_records,
// moderation_flags, admin_audit_logs) — all via the shared models package, never
// another feature's code. Each mutation runs in a transaction so the required
// audit row commits atomically with the change.
type gormRepository struct {
	db *gorm.DB
}

// NewGormRepository builds the Postgres-backed admin repository.
func NewGormRepository(db *gorm.DB) Repository {
	return &gormRepository{db: db}
}

func (r *gormRepository) UsageSummary(ctx context.Context) (UsageSummary, error) {
	db := r.db.WithContext(ctx)
	var s UsageSummary

	// Table-driven so each count is one COUNT(*) with an optional predicate. Admin
	// analytics is low-traffic, so a handful of counts is fine — no need for a
	// single hand-rolled aggregate query.
	steps := []struct {
		dst   *int64
		model any
		cond  string
		args  []any
	}{
		{&s.TotalUsers, &models.User{}, "", nil},
		{&s.TotalGenerations, &models.GenerationRecord{}, "", nil},
		{&s.TextGenerations, &models.GenerationRecord{}, "type = ?", []any{models.GenerationText}},
		{&s.ImageGenerations, &models.GenerationRecord{}, "type = ?", []any{models.GenerationImage}},
		{&s.VideoGenerations, &models.GenerationRecord{}, "type = ?", []any{models.GenerationVideo}},
		{&s.TotalFlags, &models.ModerationFlag{}, "", nil},
		{&s.PendingFlags, &models.ModerationFlag{}, "reviewed_at IS NULL", nil},
	}
	for _, st := range steps {
		q := db.Model(st.model)
		if st.cond != "" {
			q = q.Where(st.cond, st.args...)
		}
		if err := q.Count(st.dst).Error; err != nil {
			return UsageSummary{}, err
		}
	}
	return s, nil
}

func (r *gormRepository) ListFlags(ctx context.Context, onlyPending bool) ([]models.ModerationFlag, error) {
	q := r.db.WithContext(ctx).Order("created_at DESC")
	if onlyPending {
		q = q.Where("reviewed_at IS NULL")
	}
	var flags []models.ModerationFlag
	if err := q.Find(&flags).Error; err != nil {
		return nil, err
	}
	return flags, nil
}

func (r *gormRepository) FindFlagByID(ctx context.Context, id uuid.UUID) (*models.ModerationFlag, error) {
	var flag models.ModerationFlag
	if err := r.db.WithContext(ctx).First(&flag, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrFlagNotFound
		}
		return nil, err
	}
	return &flag, nil
}

func (r *gormRepository) ReviewFlag(ctx context.Context, flag *models.ModerationFlag, audit *models.AdminAuditLog) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// Conditional claim: write the review columns ONLY while the flag is still
		// unreviewed. This is the atomic backstop for the single-reviewer invariant —
		// the service's pre-check can be raced past by a second admin, but only one
		// UPDATE can match reviewed_at IS NULL. A map (not Save) touches exactly the
		// two review columns, so nothing else on the row is clobbered.
		res := tx.Model(&models.ModerationFlag{}).
			Where("id = ? AND reviewed_at IS NULL", flag.ID).
			Updates(map[string]any{
				"reviewed_by_admin_id": flag.ReviewedByAdminID,
				"reviewed_at":          flag.ReviewedAt,
			})
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			// Nothing matched: the row is either gone or already reviewed. Distinguish
			// so the service returns 404 vs 409.
			var count int64
			if err := tx.Model(&models.ModerationFlag{}).
				Where("id = ?", flag.ID).Count(&count).Error; err != nil {
				return err
			}
			if count > 0 {
				return ErrFlagAlreadyReviewed
			}
			return ErrFlagNotFound
		}
		return tx.Create(audit).Error
	})
}

func (r *gormRepository) FindUserByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	var user models.User
	if err := r.db.WithContext(ctx).First(&user, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return &user, nil
}

func (r *gormRepository) SetUserLimits(ctx context.Context, user *models.User, audit *models.AdminAuditLog) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// A map (not a struct) so a cleared override (nil → NULL) is actually
		// written — Updates on a struct skips nil/zero fields, which would make
		// "reset to default" a silent no-op. GORM bumps updated_at automatically for
		// the model's UpdatedAt field. Only the two override columns are touched, so
		// no other user field (password_hash, lockout state) is clobbered.
		res := tx.Model(user).Updates(map[string]any{
			"daily_text_quota":  user.DailyTextQuota,
			"daily_image_quota": user.DailyImageQuota,
		})
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return ErrUserNotFound
		}
		return tx.Create(audit).Error
	})
}
