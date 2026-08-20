package quota

import (
	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// RegisterRoutes mounts GET /quota/me (bearer-authenticated, openapi.yaml).
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, mw middleware.Set) {
	r.GET("/quota/me", mw.AuthRequired, h.me)
}

func (h *Handler) me(c *gin.Context) {
	httpx.Fail(c, apperror.NotImplemented("quota status"))
}
