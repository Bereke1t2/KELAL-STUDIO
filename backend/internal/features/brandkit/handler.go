package brandkit

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/validate"
)

// Handler is the delivery adapter: it binds/validates requests, resolves the
// authenticated caller, calls the service, and renders the result or an
// apperror via httpx. It holds no state beyond the service and is the type
// module.New returns.
type Handler struct {
	svc *Service
}

// NewHandler wraps a service for HTTP delivery.
func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

// get handles GET /brand-kits/{id} (bearer-authenticated). Returns the caller's
// brand kit, or 404 if it does not exist or belongs to someone else.
func (h *Handler) get(c *gin.Context) {
	ownerID, aerr := callerID(c)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	id, aerr := pathID(c)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	kit, aerr := h.svc.Get(c.Request.Context(), id, ownerID)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	httpx.OK(c, toResponse(kit))
}

// update handles PUT /brand-kits/{id} (bearer-authenticated). It is an
// owner-scoped upsert (see Service.Upsert) and returns the resulting kit with
// 200 in both the create and update cases, matching the contract.
func (h *Handler) update(c *gin.Context) {
	ownerID, aerr := callerID(c)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	id, aerr := pathID(c)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	var req brandKitRequest
	if aerr := validate.BindJSON(c, &req); aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	kit, aerr := h.svc.Upsert(c.Request.Context(), id, ownerID, req.toInput())
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	httpx.OK(c, toResponse(kit))
}

// callerID extracts the authenticated user's id from the access token the Auth
// middleware validated. A malformed value means a broken session, not a client
// error — the routes are always mounted behind mw.AuthRequired.
func callerID(c *gin.Context) (uuid.UUID, *apperror.Error) {
	id, err := uuid.Parse(middleware.UserID(c))
	if err != nil {
		return uuid.Nil, apperror.Unauthorized("invalid session")
	}
	return id, nil
}

// pathID parses the {id} path parameter, returning a 400 validation_error for a
// non-uuid value.
func pathID(c *gin.Context) (uuid.UUID, *apperror.Error) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return uuid.Nil, apperror.Validation("brand kit id must be a valid uuid")
	}
	return id, nil
}
