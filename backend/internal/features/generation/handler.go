package generation

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/validate"
)

// Handler is the delivery adapter: it binds/validates requests, calls the
// service, and renders the result or an apperror via httpx. It holds no state
// beyond the service and is the type module.New returns.
type Handler struct {
	svc *Service
}

// NewHandler wraps a service for HTTP delivery.
func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

// RegisterRoutes mounts the generation surface, all bearer-authenticated and
// rate-limited per user (openapi.yaml).
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, mw middleware.Set) {
	g := r.Group("/generate", mw.AuthRequired, mw.UserRateLimit)
	g.POST("/text", h.text)
	g.POST("/image", h.image)
	g.POST("/video", h.video)

	// Job status lives outside /generate but belongs to this feature.
	r.GET("/jobs/:id", mw.AuthRequired, h.job)
}

// text handles POST /generate/text. The full flow:
//  1. Bind + validate request body
//  2. Resolve caller identity
//  3. Load brand kit context (if brand_kit_id provided)
//  4. Delegate to service (quota → cache → provider chain → persist)
func (h *Handler) text(c *gin.Context) {
	// ── Bind request ──────────────────────────────────────────────────────
	var req generateTextRequest
	if aerr := validate.BindJSON(c, &req); aerr != nil {
		httpx.Fail(c, aerr)
		return
	}

	// ── Resolve caller ────────────────────────────────────────────────────
	userID, err := uuid.Parse(middleware.UserID(c))
	if err != nil {
		httpx.Fail(c, apperror.Unauthorized("invalid session"))
		return
	}

	// ── Load brand context (optional) ─────────────────────────────────────
	brandName, tone := h.svc.LoadBrandKit(c.Request.Context(), userID, req.BrandKitID)

	// ── Generate ──────────────────────────────────────────────────────────
	result, aerr := h.svc.GenerateText(c.Request.Context(), userID, req, brandName, tone)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}

	httpx.OK(c, result)
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
