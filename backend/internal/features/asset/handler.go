package asset

import (
	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// RegisterRoutes mounts POST /assets (bearer-authenticated, per-user rate
// limited). PRD-derived; not yet in the mobile contract.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, mw middleware.Set) {
	r.POST("/assets", mw.AuthRequired, mw.UserRateLimit, h.upload)
}

func (h *Handler) upload(c *gin.Context) {
	// TODO(asset): validate-by-content → re-encode → strip metadata → store
	// outside web root (PRD §6.8, §7.8). See the package doc for the full list.
	httpx.Fail(c, apperror.NotImplemented("asset upload"))
}
