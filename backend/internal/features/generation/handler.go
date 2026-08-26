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
// RegisterRoutes mounts the generation surface, all bearer-authenticated,
// email-verified, and rate-limited per user (openapi.yaml; PRD §6.1 gates
// generation on a verified email). Handlers return not_implemented for now.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, mw middleware.Set) {
	g := r.Group("/generate", mw.AuthRequired, mw.EmailVerified, mw.UserRateLimit)
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
	var req GenerateTextRequest
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

// image handles POST /generate/image. The full flow:
//  1. Bind + validate request body (aspect_ratio enforced as 1:1 or 4:5 — OQ-02)
//  2. Resolve caller identity
//  3. Load brand kit context (if brand_kit_id provided)
//  4. Delegate to service (quota → moderation → provider chain → persist asset → persist record)
func (h *Handler) image(c *gin.Context) {
	// ── Bind request ──────────────────────────────────────────────────────
	var req GenerateImageRequest
	if aerr := validate.BindJSON(c, &req); aerr != nil {
		httpx.Fail(c, aerr)
		return
	}

	// ── Aspect ratio guard (OQ-02) ────────────────────────────────────────
	// The contract enum allows only "1:1" and "4:5". Even though binding
	// enforces this, we add an explicit guard as a defense-in-depth layer.
	switch req.AspectRatio {
	case "1:1", "4:5":
		// allowed
	default:
		httpx.Fail(c, apperror.Validation("aspect_ratio must be 1:1 or 4:5"))
		return
	}

	// ── Resolve caller ────────────────────────────────────────────────────
	userID, err := uuid.Parse(middleware.UserID(c))
	if err != nil {
		httpx.Fail(c, apperror.Unauthorized("invalid session"))
		return
	}

	// ── Load brand context (optional) ─────────────────────────────────────
	brandName, _ := h.svc.LoadBrandKit(c.Request.Context(), userID, req.BrandKitID)

	// ── Generate ──────────────────────────────────────────────────────────
	result, aerr := h.svc.GenerateImage(c.Request.Context(), userID, req, brandName)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}

	httpx.OK(c, result)
}

// video handles POST /generate/video. Async: enqueues a job and returns 202.
// The actual processing happens in the queue consumer (ProcessVideoJob).
func (h *Handler) video(c *gin.Context) {
	// ── Bind request ──────────────────────────────────────────────────────
	var req GenerateVideoRequest
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
	brandName, _ := h.svc.LoadBrandKit(c.Request.Context(), userID, req.BrandKitID)

	// ── Enqueue ───────────────────────────────────────────────────────────
	result, aerr := h.svc.GenerateVideo(c.Request.Context(), userID, req, brandName)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}

	// 202 Accepted — the client polls GET /jobs/{id} for completion.
	httpx.Accepted(c, result)
}

// job handles GET /jobs/:id — returns the current status of an async job.
func (h *Handler) job(c *gin.Context) {
	jobID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		httpx.Fail(c, apperror.Validation("invalid job id"))
		return
	}

	result, aerr := h.svc.GetJob(c.Request.Context(), jobID)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}

	httpx.OK(c, result)
}
