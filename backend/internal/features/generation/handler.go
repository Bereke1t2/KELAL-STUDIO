package generation

import (
	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// RegisterRoutes mounts the generation surface, all bearer-authenticated and
// rate-limited per user (openapi.yaml). Handlers return not_implemented for now.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, mw middleware.Set) {
	g := r.Group("/generate", mw.AuthRequired, mw.UserRateLimit)
	g.POST("/text", h.text)
	g.POST("/image", h.image)
	g.POST("/video", h.video)

	// Job status lives outside /generate but belongs to this feature.
	r.GET("/jobs/:id", mw.AuthRequired, h.job)
}

func (h *Handler) text(c *gin.Context) {
	httpx.Fail(c, apperror.NotImplemented("text generation"))
}

func (h *Handler) image(c *gin.Context) {
	// TODO(generation): reject any aspect_ratio other than "1:1"/"4:5" with a
	// validation_error BEFORE calling the provider (OQ-02).
	httpx.Fail(c, apperror.NotImplemented("image generation"))
}

func (h *Handler) video(c *gin.Context) {
	// TODO(generation): enqueue via platform/queue and return 202 + Job.
	httpx.Fail(c, apperror.NotImplemented("video generation"))
}

func (h *Handler) job(c *gin.Context) {
	httpx.Fail(c, apperror.NotImplemented("job status"))
}
