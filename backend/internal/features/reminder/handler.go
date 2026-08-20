package reminder

import (
	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// RegisterRoutes mounts POST /reminders (bearer-authenticated, openapi.yaml).
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, mw middleware.Set) {
	r.POST("/reminders", mw.AuthRequired, h.create)
}

func (h *Handler) create(c *gin.Context) {
	// TODO(reminder): validate scheduled_at_utc is UTC and in the future; treat
	// draft_local_id as an opaque string (OQ-05, no drafts table).
	httpx.Fail(c, apperror.NotImplemented("reminders"))
}
