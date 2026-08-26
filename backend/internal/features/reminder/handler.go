package reminder

import (
	"fmt"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/validate"
)

// Handler is the delivery adapter for the reminder feature.
type Handler struct {
	svc *Service
}

// NewHandler wraps a service for HTTP delivery.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes mounts POST /reminders (bearer-authenticated, openapi.yaml).
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, mw middleware.Set) {
	r.POST("/reminders", mw.AuthRequired, h.create)
}

// createReminderRequest mirrors the openapi.yaml schema.
type createReminderRequest struct {
	DraftLocalID   string `json:"draft_local_id" binding:"required"`
	ScheduledAtUTC string `json:"scheduled_at_utc" binding:"required"`
}

func (h *Handler) create(c *gin.Context) {
	// ── Bind request ──────────────────────────────────────────────────────
	var req createReminderRequest
	if aerr := validate.BindJSON(c, &req); aerr != nil {
		httpx.Fail(c, aerr)
		return
	}

	// ── Resolve caller ────────────────────────────────────────────────────
	userID, err := uuid.Parse(middleware.UserID(c))
	if err != nil {
		httpx.Fail(c, apperror.Unauthorized("invalid session"))
		return
	}

	// ── Parse scheduled_at_utc ────────────────────────────────────────────
	// Must be RFC3339 / ISO 8601. Always stored as UTC (PRD §6.12).
	scheduledAt, err := parseUTCTime(req.ScheduledAtUTC)
	if err != nil {
		httpx.Fail(c, apperror.Validation("scheduled_at_utc must be a valid RFC3339 UTC timestamp"))
		return
	}

	// ── Create reminder ───────────────────────────────────────────────────
	result, aerr := h.svc.CreateReminder(c.Request.Context(), userID, CreateReminderRequest{
		DraftLocalID:   req.DraftLocalID,
		ScheduledAtUTC: scheduledAt,
	})
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}

	httpx.Created(c, result)
}

// parseUTCTime parses an RFC3339 timestamp and ensures it's in UTC.
func parseUTCTime(s string) (time.Time, error) {
	parsed, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return time.Time{}, err
	}
	// Verify the time is UTC (no timezone offset or +00:00).
	if parsed.Location() != time.UTC {
		return time.Time{}, fmt.Errorf("timestamp must be UTC")
	}
	return parsed, nil
}
