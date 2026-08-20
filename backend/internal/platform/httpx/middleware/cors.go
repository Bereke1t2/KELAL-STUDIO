package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// CORS applies permissive cross-origin headers.
//
// NOTE (scaffold): "*" is fine for the mobile app (Bearer tokens, no cookies),
// but the admin web portal (PRD §6.13) will want an explicit allow-list once it
// exists. Tighten to configured origins before shipping the portal — flagged in
// docs/OPEN_QUESTIONS.md.
func CORS() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Authorization, Content-Type, "+HeaderRequestID)
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}
