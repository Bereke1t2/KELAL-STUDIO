package admin

import (
	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// RegisterRoutes mounts the /admin surface, gated by auth AND the admin role.
// Backend-spec (PRD §6.13); not in the mobile contract.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, mw middleware.Set) {
	g := r.Group("/admin", mw.AuthRequired, mw.AdminOnly)
	g.GET("/usage", h.usage)
	g.GET("/flags", h.flags)
	g.POST("/flags/:id/review", h.reviewFlag)
	g.PUT("/users/:id/limits", h.setUserLimits)
}

func (h *Handler) usage(c *gin.Context) {
	httpx.Fail(c, apperror.NotImplemented("admin usage report"))
}

func (h *Handler) flags(c *gin.Context) {
	httpx.Fail(c, apperror.NotImplemented("admin moderation flag queue"))
}

func (h *Handler) reviewFlag(c *gin.Context) {
	// TODO(admin): write a models.AdminAuditLog row for this review action.
	httpx.Fail(c, apperror.NotImplemented("admin flag review"))
}

func (h *Handler) setUserLimits(c *gin.Context) {
	// TODO(admin): write a models.AdminAuditLog row for this limit override.
	httpx.Fail(c, apperror.NotImplemented("admin user limit override"))
}
