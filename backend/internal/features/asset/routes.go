package asset

import (
	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// RegisterRoutes mounts POST /assets — bearer-authenticated and per-user rate
// limited (api/openapi.yaml). It is intentionally NOT gated on email
// verification: uploading a logo is part of setting up a brand kit, and only
// content GENERATION is verification-gated (PRD §6.1). This signature —
// (r *gin.RouterGroup, mw middleware.Set) — is the one every feature's
// RegisterRoutes copies, so cmd/api wires them all uniformly.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, mw middleware.Set) {
	r.POST("/assets", mw.AuthRequired, mw.UserRateLimit, h.upload)
}
