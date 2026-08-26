package auth

import (
	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// RegisterRoutes mounts the auth surface under the given /v1 group. The public
// routes (register/login/refresh/password-reset/verify-email) take no auth
// middleware — each is either unauthenticated by design or authenticated by a
// token in its own body; only DELETE /account requires a valid access token.
// This signature — (r *gin.RouterGroup, mw middleware.Set) — is the one every
// feature's RegisterRoutes copies, so cmd/api wires them all uniformly.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, mw middleware.Set) {
	g := r.Group("/auth")
	g.POST("/register", h.register)
	g.POST("/login", h.login)
	g.POST("/refresh", h.refresh)
	g.POST("/password-reset/request", h.requestPasswordReset)
	g.POST("/password-reset/confirm", h.confirmPasswordReset)
	g.POST("/verify-email", h.verifyEmail)
	g.POST("/verify-email/resend", h.resendVerification)
	g.DELETE("/account", mw.AuthRequired, h.deleteAccount)
}
