package middleware

import (
	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
)

// EmailVerifiedRequired blocks a request whose access token is not email-verified
// (PRD §6.1: verification gates content generation). It reads the claim stashed
// by Auth, so it MUST be chained AFTER AuthRequired — on its own it fails closed
// (an unauthenticated request has no claim and is rejected).
//
// The claim reflects verification state at token-mint time, so a user who
// verifies mid-session keeps hitting the gate until their next token refresh
// (≤ access TTL). That lag is acceptable for a one-time onboarding step.
func EmailVerifiedRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !EmailVerified(c) {
			httpx.Fail(c, apperror.EmailNotVerified("verify your email address to generate content"))
			return
		}
		c.Next()
	}
}
