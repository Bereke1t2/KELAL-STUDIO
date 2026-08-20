// Package validate wraps gin's request binding so every handler produces the
// same contract-shaped validation_error (apperror) instead of gin's raw
// validator output. Handlers call validate.BindJSON and, on a non-nil return,
// hand it straight to httpx.Fail.
package validate

import (
	"errors"
	"fmt"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
)

// BindJSON binds and validates the JSON request body into dst. On failure it
// returns an *apperror.Error (CodeValidationError) with a human-readable
// message; on success it returns nil.
func BindJSON(c *gin.Context, dst any) *apperror.Error {
	if err := c.ShouldBindJSON(dst); err != nil {
		return apperror.Validation(humanize(err))
	}
	return nil
}

func humanize(err error) string {
	var ve validator.ValidationErrors
	if errors.As(err, &ve) {
		parts := make([]string, 0, len(ve))
		for _, fe := range ve {
			parts = append(parts, fmt.Sprintf("'%s' failed rule '%s'", fe.Field(), fe.Tag()))
		}
		return "validation failed: " + strings.Join(parts, ", ")
	}
	// Malformed JSON, wrong types, etc.
	return "invalid or malformed request body"
}
