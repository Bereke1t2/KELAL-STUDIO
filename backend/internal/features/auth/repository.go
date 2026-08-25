package auth

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// gormRepository is the real Repository adapter over Postgres. It translates
// GORM's errors into the feature's domain sentinels so the service never sees a
// driver-specific error. GORM is configured with TranslateError (see
// platform/database), so duplicate keys surface as gorm.ErrDuplicatedKey.
type gormRepository struct {
	db *gorm.DB
}

// NewGormRepository builds the Postgres-backed auth repository.
func NewGormRepository(db *gorm.DB) Repository {
	return &gormRepository{db: db}
}

func (r *gormRepository) CreateUser(ctx context.Context, u *models.User) error {
	if err := r.db.WithContext(ctx).Create(u).Error; err != nil {
		if errors.Is(err, gorm.ErrDuplicatedKey) {
			return ErrEmailTaken
		}
		return err
	}
	return nil
}

func (r *gormRepository) FindUserByEmail(ctx context.Context, email string) (*models.User, error) {
	var u models.User
	if err := r.db.WithContext(ctx).Where("email = ?", email).First(&u).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return &u, nil
}

func (r *gormRepository) FindUserByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	var u models.User
	if err := r.db.WithContext(ctx).First(&u, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return &u, nil
}

func (r *gormRepository) UpdateUserPassword(ctx context.Context, id uuid.UUID, expectedVersion int, passwordHash string) error {
	// Version-conditional + atomic bump: the row updates only while its
	// token_version still matches the value the reset token carried, and the same
	// statement increments it — so the token is single-use. GORM's soft-delete
	// scope also excludes deleted rows. A version mismatch and a missing user both
	// yield 0 rows → ErrUserNotFound (indistinguishable, by design).
	res := r.db.WithContext(ctx).
		Model(&models.User{}).
		Where("id = ? AND token_version = ?", id, expectedVersion).
		Updates(map[string]any{
			"password_hash": passwordHash,
			"token_version": gorm.Expr("token_version + 1"),
		})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrUserNotFound
	}
	return nil
}

func (r *gormRepository) MarkEmailVerified(ctx context.Context, id uuid.UUID) error {
	now := time.Now()
	// Idempotent: only stamp when not already verified, so a replayed token
	// doesn't move the timestamp. 0 rows then means "already verified" OR "no such
	// user" — a follow-up existence check disambiguates so a genuinely missing
	// user still surfaces ErrUserNotFound.
	res := r.db.WithContext(ctx).
		Model(&models.User{}).
		Where("id = ? AND email_verified_at IS NULL", id).
		Update("email_verified_at", now)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected > 0 {
		return nil
	}
	var count int64
	if err := r.db.WithContext(ctx).Model(&models.User{}).Where("id = ?", id).Count(&count).Error; err != nil {
		return err
	}
	if count == 0 {
		return ErrUserNotFound
	}
	return nil // already verified — idempotent success
}

func (r *gormRepository) SoftDeleteUser(ctx context.Context, id uuid.UUID) error {
	// GORM turns Delete into a soft delete because User has gorm.DeletedAt.
	res := r.db.WithContext(ctx).Delete(&models.User{}, "id = ?", id)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrUserNotFound
	}
	return nil
}

func (r *gormRepository) IncrementFailedLoginAttempts(ctx context.Context, id uuid.UUID) (int, error) {
	// Atomic increment-and-return via Postgres RETURNING, so concurrent failed
	// logins can't lose a count to a read-modify-write race.
	u := models.User{Base: models.Base{ID: id}}
	res := r.db.WithContext(ctx).
		Model(&u).
		Clauses(clause.Returning{Columns: []clause.Column{{Name: "failed_login_attempts"}}}).
		Where("id = ?", id).
		Update("failed_login_attempts", gorm.Expr("failed_login_attempts + 1"))
	if res.Error != nil {
		return 0, res.Error
	}
	if res.RowsAffected == 0 {
		return 0, ErrUserNotFound
	}
	return u.FailedLoginAttempts, nil
}

func (r *gormRepository) LockUser(ctx context.Context, id uuid.UUID, until time.Time) error {
	res := r.db.WithContext(ctx).
		Model(&models.User{}).
		Where("id = ?", id).
		Updates(map[string]any{"locked_until": until, "failed_login_attempts": 0})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrUserNotFound
	}
	return nil
}

func (r *gormRepository) ResetFailedLoginAttempts(ctx context.Context, id uuid.UUID) error {
	res := r.db.WithContext(ctx).
		Model(&models.User{}).
		Where("id = ?", id).
		Updates(map[string]any{"failed_login_attempts": 0, "locked_until": nil})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrUserNotFound
	}
	return nil
}

func (r *gormRepository) CreateRefreshToken(ctx context.Context, rt *models.RefreshToken) error {
	return r.db.WithContext(ctx).Create(rt).Error
}

func (r *gormRepository) FindRefreshTokenByID(ctx context.Context, id uuid.UUID) (*models.RefreshToken, error) {
	var rt models.RefreshToken
	if err := r.db.WithContext(ctx).First(&rt, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrRefreshTokenNotFound
		}
		return nil, err
	}
	return &rt, nil
}

func (r *gormRepository) RevokeRefreshToken(ctx context.Context, id uuid.UUID) error {
	now := time.Now()
	// Only touch a live row so this is idempotent and never resurrects a
	// revoked_at timestamp.
	return r.db.WithContext(ctx).
		Model(&models.RefreshToken{}).
		Where("id = ? AND revoked_at IS NULL", id).
		Update("revoked_at", now).Error
}

func (r *gormRepository) RevokeAllUserRefreshTokens(ctx context.Context, userID uuid.UUID) error {
	now := time.Now()
	return r.db.WithContext(ctx).
		Model(&models.RefreshToken{}).
		Where("user_id = ? AND revoked_at IS NULL", userID).
		Update("revoked_at", now).Error
}
