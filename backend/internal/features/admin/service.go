package admin

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
)

// Audit action labels recorded in models.AdminAuditLog.Action — the stable,
// machine-readable record of what an admin did.
const (
	auditActionReviewFlag    = "flag.review"
	auditActionSetUserLimits = "user.set_limits"
)

// Service holds the admin use cases. Each public method is ONE use case and
// returns (result, *apperror.Error) — failures are values the delivery layer
// renders, never panics. The service depends only on the Repository port, never
// on GORM or gin.
type Service struct {
	repo Repository
	log  *slog.Logger
}

// NewService wires the use cases.
func NewService(repo Repository, log *slog.Logger) *Service {
	return &Service{repo: repo, log: log}
}

// Usage returns aggregate usage analytics (GET /admin/usage). Read-only, so no
// audit row is written.
func (s *Service) Usage(ctx context.Context) (UsageSummary, *apperror.Error) {
	sum, err := s.repo.UsageSummary(ctx)
	if err != nil {
		return UsageSummary{}, apperror.Internal(err)
	}
	return sum, nil
}

// ListFlags returns the moderation-flag review queue (GET /admin/flags).
// Read-only, so no audit row is written. onlyPending restricts it to flags not
// yet reviewed.
func (s *Service) ListFlags(ctx context.Context, onlyPending bool) ([]models.ModerationFlag, *apperror.Error) {
	flags, err := s.repo.ListFlags(ctx, onlyPending)
	if err != nil {
		return nil, apperror.Internal(err)
	}
	return flags, nil
}

// ReviewFlag adjudicates a moderation flag (POST /admin/flags/{id}/review): it
// marks the flag reviewed by the calling admin and writes an audit row in the
// same transaction.
//
// Re-reviewing an already-reviewed flag is a 409 Conflict, not a silent
// overwrite — the flag records a SINGLE reviewer and timestamp, and clobbering
// them would erase who first adjudicated it. The pre-check below is the fast
// path; the repository re-checks atomically (a conditional claim on
// reviewed_at IS NULL) so two admins racing past it can't both win. Each review
// is a distinct, audited act.
func (s *Service) ReviewFlag(ctx context.Context, flagID, adminID uuid.UUID) (*models.ModerationFlag, *apperror.Error) {
	flag, err := s.repo.FindFlagByID(ctx, flagID)
	if err != nil {
		if errors.Is(err, ErrFlagNotFound) {
			return nil, apperror.NotFound("moderation flag not found")
		}
		return nil, apperror.Internal(err)
	}
	if flag.ReviewedAt != nil {
		return nil, apperror.Conflict("moderation flag has already been reviewed")
	}

	now := time.Now()
	flag.ReviewedByAdminID = &adminID
	flag.ReviewedAt = &now

	audit := &models.AdminAuditLog{
		AdminUserID: adminID,
		Action:      auditActionReviewFlag,
		TargetRef:   targetRef("flag", flagID),
		CreatedAt:   now,
	}
	if err := s.repo.ReviewFlag(ctx, flag, audit); err != nil {
		switch {
		case errors.Is(err, ErrFlagNotFound):
			return nil, apperror.NotFound("moderation flag not found")
		case errors.Is(err, ErrFlagAlreadyReviewed):
			// Lost the race to a concurrent reviewer — same 409 as the pre-check.
			return nil, apperror.Conflict("moderation flag has already been reviewed")
		default:
			return nil, apperror.Internal(err)
		}
	}
	s.log.Info("admin reviewed moderation flag", "admin_id", adminID, "flag_id", flagID)
	return flag, nil
}

// SetUserLimits overrides a user's per-user daily generation caps (PUT
// /admin/users/{id}/limits) and writes an audit row in the same transaction. A
// nil field clears that override (fall back to the global default). Negative caps
// are rejected; zero is allowed (an explicit "block all").
func (s *Service) SetUserLimits(ctx context.Context, targetUserID, adminID uuid.UUID, in LimitsInput) (*models.User, *apperror.Error) {
	if in.DailyTextQuota != nil && *in.DailyTextQuota < 0 {
		return nil, apperror.Validation("daily_text_quota must not be negative")
	}
	if in.DailyImageQuota != nil && *in.DailyImageQuota < 0 {
		return nil, apperror.Validation("daily_image_quota must not be negative")
	}

	user, err := s.repo.FindUserByID(ctx, targetUserID)
	if err != nil {
		if errors.Is(err, ErrUserNotFound) {
			return nil, apperror.NotFound("user not found")
		}
		return nil, apperror.Internal(err)
	}

	user.DailyTextQuota = in.DailyTextQuota
	user.DailyImageQuota = in.DailyImageQuota

	audit := &models.AdminAuditLog{
		AdminUserID: adminID,
		Action:      auditActionSetUserLimits,
		TargetRef:   targetRef("user", targetUserID),
		CreatedAt:   time.Now(),
	}
	if err := s.repo.SetUserLimits(ctx, user, audit); err != nil {
		if errors.Is(err, ErrUserNotFound) {
			return nil, apperror.NotFound("user not found")
		}
		return nil, apperror.Internal(err)
	}
	s.log.Info("admin set user limits", "admin_id", adminID, "user_id", targetUserID,
		"daily_text_quota", in.DailyTextQuota, "daily_image_quota", in.DailyImageQuota)
	return user, nil
}

// targetRef formats an AdminAuditLog.TargetRef as "<kind>:<id>" (e.g.
// "flag:<uuid>", "user:<uuid>") so the audit trail names the affected entity.
func targetRef(kind string, id uuid.UUID) string {
	return fmt.Sprintf("%s:%s", kind, id)
}
