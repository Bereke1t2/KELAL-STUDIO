package middleware

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// HeaderRequestID is the request-correlation header, propagated in and out.
const HeaderRequestID = "X-Request-ID"

const ctxRequestID = "req.id"

// RequestID ensures every request has a correlation id: it honors an incoming
// X-Request-ID or mints one, stashes it on the context, and echoes it back on
// the response so clients and logs can be tied together.
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.GetHeader(HeaderRequestID)
		if id == "" {
			id = uuid.NewString()
		}
		c.Set(ctxRequestID, id)
		c.Header(HeaderRequestID, id)
		c.Next()
	}
}

// RequestIDOf returns the correlation id for the current request, or "".
func RequestIDOf(c *gin.Context) string {
	if v, ok := c.Get(ctxRequestID); ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}
