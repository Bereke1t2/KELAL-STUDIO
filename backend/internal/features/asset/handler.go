package asset

import (
	"errors"
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/storage"
)

// multipartOverhead is slack added to the byte cap when bounding the request
// stream, to allow for the multipart envelope (boundaries, the
// Content-Disposition headers) wrapping the file part — so a file at exactly the
// limit isn't rejected by the framing. The service re-checks the actual file
// bytes against the exact cap.
const multipartOverhead = 1 << 20 // 1 MiB

// Handler is the asset delivery adapter: it bounds and reads the multipart
// upload, resolves the authenticated caller, calls the service, and renders the
// result or an apperror via httpx. It holds no state beyond the service and is
// the type module.New returns.
type Handler struct {
	svc *Service
}

// NewHandler wraps a service for HTTP delivery.
func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

// upload handles POST /assets (bearer-authenticated, per-user rate limited). It
// accepts a single multipart "file" part, hardens it (see Service.Upload), and
// returns 201 with the created asset. Every client-input failure is a 400.
func (h *Handler) upload(c *gin.Context) {
	ownerID, aerr := callerID(c)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}

	// Bound the request body BEFORE parsing multipart, so an oversized or endless
	// stream is cut off rather than buffered whole. The cap is the byte limit plus
	// slack for the multipart envelope.
	maxBody := h.svc.cfg.MaxBytes + multipartOverhead
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBody)

	fileHeader, err := c.FormFile("file")
	if err != nil {
		// Either no "file" part, or the body tripped MaxBytesReader while parsing.
		httpx.Fail(c, apperror.Validation("attach an image in the 'file' field (and stay within the size limit)"))
		return
	}
	if fileHeader.Size > h.svc.cfg.MaxBytes {
		httpx.Fail(c, apperror.Validation("the image exceeds the maximum allowed size"))
		return
	}

	f, err := fileHeader.Open()
	if err != nil {
		httpx.Fail(c, apperror.Validation("the uploaded file could not be read"))
		return
	}
	defer func() { _ = f.Close() }()

	// Read at most MaxBytes+1 so an over-cap file is caught by the service without
	// trusting the client-declared part size.
	raw, err := io.ReadAll(io.LimitReader(f, h.svc.cfg.MaxBytes+1))
	if err != nil {
		httpx.Fail(c, apperror.Validation("the uploaded file could not be read"))
		return
	}

	asset, aerr := h.svc.Upload(c.Request.Context(), ownerID, raw)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	httpx.Created(c, toResponse(asset))
}

// serve handles GET /assets/:id — streams the image bytes back to the
// caller with the correct Content-Type. The route is bearer-authenticated.
func (h *Handler) serve(c *gin.Context) {
	ownerID, aerr := callerID(c)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}

	assetID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		httpx.Fail(c, apperror.Validation("invalid asset id"))
		return
	}

	asset, data, svcErr := h.svc.Get(c.Request.Context(), assetID)
	if svcErr != nil {
		if errors.Is(svcErr, storage.ErrNotFound) {
			httpx.Fail(c, apperror.NotFound("asset"))
			return
		}
		httpx.Fail(c, apperror.Internal(svcErr))
		return
	}
	if asset == nil {
		httpx.Fail(c, apperror.NotFound("asset"))
		return
	}

	// Authorization: the caller must own the asset.
	if asset.OwnerUserID != ownerID {
		httpx.Fail(c, apperror.NotFound("asset"))
		return
	}

	c.Header("Content-Type", asset.MimeType)
	c.Header("Cache-Control", "private, max-age=86400")
	c.Data(http.StatusOK, asset.MimeType, data)
}

// callerID extracts the authenticated user's id from the access token the Auth
// middleware validated. A malformed value means a broken session, not a client
// error — the route is always mounted behind mw.AuthRequired.
func callerID(c *gin.Context) (uuid.UUID, *apperror.Error) {
	id, err := uuid.Parse(middleware.UserID(c))
	if err != nil {
		return uuid.Nil, apperror.Unauthorized("invalid session")
	}
	return id, nil
}
