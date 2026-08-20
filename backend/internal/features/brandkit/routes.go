package brandkit

import (
	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// RegisterRoutes mounts GET/PUT /brand-kits/:id, both bearer-authenticated
// (api/openapi.yaml). This signature — (r *gin.RouterGroup, mw middleware.Set)
// — is the one every feature's RegisterRoutes copies, so cmd/api wires them all
// uniformly.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, mw middleware.Set) {
	g := r.Group("/brand-kits", mw.AuthRequired)
	g.GET("/:id", h.get)
	g.PUT("/:id", h.update)
}
