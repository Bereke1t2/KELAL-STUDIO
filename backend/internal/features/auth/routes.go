package auth

import (
	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// RegisterRoutes mounts the auth surface under the given /v1 group. The public
// routes (register/login/refresh/password-reset) take no auth middleware; only
// DELETE /account requires a valid access token. This signature —
// (r *gin.RouterGroup, mw middleware.Set) — is the one every feature's
// RegisterRoutes copies, so cmd/api wires them all uniformly.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, mw middleware.Set) {
	g := r.Group("/auth")
	g.POST("/register", h.register)
	g.POST("/login", h.login)
	g.POST("/refresh", h.refresh)
	g.POST("/password-reset/request", h.requestPasswordReset)
	g.POST("/password-reset/confirm", h.confirmPasswordReset)
	g.DELETE("/account", mw.AuthRequired, h.deleteAccount)
}
