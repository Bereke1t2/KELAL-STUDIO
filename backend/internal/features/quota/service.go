package quota

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
)

// Service holds the quota use cases. Enforce() is called by the generation
// feature BEFORE any outbound provider call (PRD §6.14).
type Service struct {
	repo   Repository
	limits QuotaLimits
	log    *slog.Logger
}

// NewService wires the quota use cases.
func NewService(repo Repository, limits QuotaLimits, log *slog.Logger) *Service {
	return &Service{
		repo:   repo,
		limits: limits,
		log:    log,
	}
}

// Enforce checks (and atomically increments) the daily quota for the given
// generation type. If the cap is exceeded it returns an apperror.QuotaExceeded
// with the reset time (midnight UTC). On success it returns nil — the caller
// proceeds to the provider chain.
func (s *Service) Enforce(ctx context.Context, userID uuid.UUID, genType models.GenerationType) *apperror.Error {
	cap := s.capForType(genType)
	if cap <= 0 {
		// No cap configured — allow everything.
		return nil
	}

	_, resetsAtRaw, err := s.repo.UpsertAndCheck(ctx, userID, genType)
	if err != nil {
		s.log.Error("failed to enforce quota",
			"user_id", userID.String(),
			"type", string(genType),
			"error", err.Error(),
		)
		return apperror.Internal(err)
	}

	// Check current usage AFTER the upsert to see if we just crossed the cap.
	textUsed, imageUsed, err := s.repo.GetTodayUsage(ctx, userID)
	if err != nil {
		s.log.Error("failed to read quota usage after upsert",
			"user_id", userID.String(),
			"error", err.Error(),
		)
		return apperror.Internal(err)
	}

	var used int
	switch genType {
	case models.GenerationText:
		used = textUsed
	case models.GenerationImage:
		used = imageUsed
	}

	if used > cap {
		// Type-assert the resetsAt to time.Time.
		midnight, _ := resetsAtRaw.(time.Time)
		if midnight.IsZero() {
			midnight = time.Now().UTC().Truncate(24 * time.Hour).Add(24 * time.Hour)
		}
		return apperror.QuotaExceeded(
			fmt.Sprintf("daily %s generation limit of %d reached", genType, cap),
			midnight,
		)
	}

	return nil
}

// GetUsage returns the current day's consumption for the quota status endpoint.
func (s *Service) GetUsage(ctx context.Context, userID uuid.UUID) (UsageResponse, *apperror.Error) {
	textUsed, imageUsed, err := s.repo.GetTodayUsage(ctx, userID)
	if err != nil {
		s.log.Error("failed to get quota usage",
			"user_id", userID.String(),
			"error", err.Error(),
		)
		return UsageResponse{}, apperror.Internal(err)
	}

	return UsageResponse{
		TextUsed:  textUsed,
		TextCap:   s.limits.TextDaily,
		ImageUsed: imageUsed,
		ImageCap:  s.limits.ImageDaily,
	}, nil
}

// capForType returns the daily cap for the given generation type.
func (s *Service) capForType(genType models.GenerationType) int {
	switch genType {
	case models.GenerationText:
		return s.limits.TextDaily
	case models.GenerationImage:
		return s.limits.ImageDaily
	default:
		return 0
	}
}
