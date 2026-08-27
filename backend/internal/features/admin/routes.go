package admin

import (
	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// RegisterRoutes mounts the /admin surface, gated by auth AND the admin role
// (mw.AuthRequired + mw.AdminOnly) — every route requires an admin session, and
// the two mutating routes additionally write an AdminAuditLog row in the service.
// Backend-only (PRD §6.13); not in the mobile contract. This signature —
// (r *gin.RouterGroup, mw middleware.Set) — is the one every feature's
// RegisterRoutes copies, so cmd/api wires them all uniformly.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, mw middleware.Set) {
	g := r.Group("/admin", mw.AuthRequired, mw.AdminOnly)
	g.GET("/usage", h.usage)
	g.GET("/flags", h.flags)
	g.POST("/flags/:id/review", h.reviewFlag)
	g.PUT("/users/:id/limits", h.setUserLimits)
}
