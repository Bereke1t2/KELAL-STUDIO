package admin

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/validate"
)

// Handler is the admin delivery adapter: it resolves the authenticated admin
// caller, binds/validates requests, calls the service, and renders the result or
// an apperror via httpx. It holds no state beyond the service and is the type
// module.New returns.
type Handler struct {
	svc *Service
}

// NewHandler wraps a service for HTTP delivery.
func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

// usage handles GET /admin/usage — aggregate usage analytics. Read-only.
func (h *Handler) usage(c *gin.Context) {
	sum, aerr := h.svc.Usage(c.Request.Context())
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	httpx.OK(c, toUsageResponse(sum))
}

// flags handles GET /admin/flags — the moderation-flag review queue. The optional
// ?status=pending query narrows it to unreviewed flags; any other value (or none)
// returns all flags.
func (h *Handler) flags(c *gin.Context) {
	onlyPending := c.Query("status") == "pending"
	flags, aerr := h.svc.ListFlags(c.Request.Context(), onlyPending)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	httpx.OK(c, toFlagsResponse(flags))
}

// reviewFlag handles POST /admin/flags/{id}/review — marks a flag adjudicated by
// the calling admin and writes an audit row. The action itself is the payload, so
// the request is bodyless.
func (h *Handler) reviewFlag(c *gin.Context) {
	adminID, aerr := callerID(c)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	flagID, aerr := pathID(c, "flag")
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	flag, aerr := h.svc.ReviewFlag(c.Request.Context(), flagID, adminID)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	httpx.OK(c, toFlagResponse(flag))
}

// setUserLimits handles PUT /admin/users/{id}/limits — overrides a user's daily
// generation caps and writes an audit row.
func (h *Handler) setUserLimits(c *gin.Context) {
	adminID, aerr := callerID(c)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	userID, aerr := pathID(c, "user")
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	var req setLimitsRequest
	if aerr := validate.BindJSON(c, &req); aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	user, aerr := h.svc.SetUserLimits(c.Request.Context(), userID, adminID, req.toInput())
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	httpx.OK(c, toUserLimitsResponse(user))
}

// callerID extracts the authenticated admin's id from the access token the Auth
// middleware validated. The routes are always mounted behind mw.AuthRequired +
// mw.AdminOnly, so a missing/invalid id is a broken session, not a client error.
func callerID(c *gin.Context) (uuid.UUID, *apperror.Error) {
	id, err := uuid.Parse(middleware.UserID(c))
	if err != nil {
		return uuid.Nil, apperror.Unauthorized("invalid session")
	}
	return id, nil
}

// pathID parses the {id} path parameter, returning a 400 validation_error naming
// the entity for a non-uuid value.
func pathID(c *gin.Context, entity string) (uuid.UUID, *apperror.Error) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return uuid.Nil, apperror.Validation(entity + " id must be a valid uuid")
	}
	return id, nil
}
