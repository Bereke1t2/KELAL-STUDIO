package middleware

import (
	"fmt"
	"log/slog"

	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
)

// Recover turns a panic in any handler into a logged, opaque 500 in the error
// taxonomy shape — so a bug in one feature never takes the process down or
// leaks a stack trace to the client.
func Recover(log *slog.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if r := recover(); r != nil {
				log.Error("panic recovered",
					"panic", fmt.Sprint(r),
					"request_id", RequestIDOf(c),
					"path", c.Request.URL.Path,
				)
				httpx.Fail(c, apperror.Internal(fmt.Errorf("panic: %v", r)))
			}
		}()
		c.Next()
	}
}
