// Package middleware holds the gin middleware: authentication, authorization,
// rate limiting, request IDs, structured request logging, panic recovery, and
// CORS. It imports httpx (for the shared Fail writer) but nothing imports it
// back except cmd/ and features — the arrows point one way.
package middleware

import (
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
)

// Context keys for values this middleware sets. Unexported so nothing pokes at
// them directly — use the accessor functions below.
const (
	ctxUserID = "auth.uid"
	ctxRole   = "auth.role"
)

// Auth validates the Bearer access token and stashes the user id + role on the
// context. On any failure it writes a generic 401 (never revealing whether the
// token was missing, malformed, or expired) and aborts.
func Auth(m *auth.Manager) gin.HandlerFunc {
	const prefix = "Bearer "
	return func(c *gin.Context) {
		h := c.GetHeader("Authorization")
		if !strings.HasPrefix(h, prefix) {
			httpx.Fail(c, apperror.Unauthorized("missing or malformed Authorization header"))
			return
		}
		claims, err := m.ParseAccess(strings.TrimSpace(strings.TrimPrefix(h, prefix)))
		if err != nil {
			httpx.Fail(c, apperror.Unauthorized("invalid or expired token"))
			return
		}
		c.Set(ctxUserID, claims.UserID)
		c.Set(ctxRole, claims.Role)
		c.Next()
	}
}

// UserID returns the authenticated user's id, or "" if the request wasn't
// authenticated (route not behind Auth).
func UserID(c *gin.Context) string {
	if v, ok := c.Get(ctxUserID); ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

// Role returns the authenticated user's role, or "".
func Role(c *gin.Context) string {
	if v, ok := c.Get(ctxRole); ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}
