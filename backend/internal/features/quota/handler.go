package quota

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// Handler is the delivery adapter for the quota feature.
type Handler struct {
	svc *Service
}

// NewHandler wraps a service for HTTP delivery.
func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

// RegisterRoutes mounts GET /quota/me (bearer-authenticated, openapi.yaml).
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, mw middleware.Set) {
	r.GET("/quota/me", mw.AuthRequired, h.me)
}

func (h *Handler) me(c *gin.Context) {
	userID, err := uuid.Parse(middleware.UserID(c))
	if err != nil {
		httpx.Fail(c, apperror.Unauthorized("invalid session"))
		return
	}

	usage, aerr := h.svc.GetUsage(c.Request.Context(), userID)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}

	httpx.OK(c, usage)
}
