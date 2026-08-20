package middleware

import (
	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
)

// AdminOnly rejects non-admin callers with 403. It reads the role set by Auth,
// so it MUST be chained after Auth (e.g. group.Use(mw.AuthRequired, mw.AdminOnly)).
// All admin endpoints are additionally audit-logged in the admin feature (PRD §6.13).
func AdminOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		if Role(c) != auth.RoleAdmin {
			httpx.Fail(c, apperror.Forbidden("admin privileges required"))
			return
		}
		c.Next()
	}
}
