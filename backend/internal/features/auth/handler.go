package auth

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

// register handles POST /auth/register. Per PRD §11 it returns
// {user_id, verification_sent} with 201 Created — NOT a session. (This diverges
// from the originally-generated mobile client, which expected AuthTokens; mobile
// must regenerate against the updated contract. See docs/OPEN_QUESTIONS.md,
// register-verification.)
func (h *Handler) register(c *gin.Context) {
	var req registerRequest
	if aerr := validate.BindJSON(c, &req); aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	res, aerr := h.svc.Register(c.Request.Context(), req.Email, req.Password)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	httpx.Created(c, registerResultToResponse(res))
}

// login handles POST /auth/login.
func (h *Handler) login(c *gin.Context) {
	var req loginRequest
	if aerr := validate.BindJSON(c, &req); aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	tokens, aerr := h.svc.Login(c.Request.Context(), req.Email, req.Password)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	httpx.OK(c, tokensToResponse(tokens))
}

// refresh handles POST /auth/refresh (rotation + reuse detection).
func (h *Handler) refresh(c *gin.Context) {
	var req refreshRequest
	if aerr := validate.BindJSON(c, &req); aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	tokens, aerr := h.svc.Refresh(c.Request.Context(), req.RefreshToken)
	if aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	httpx.OK(c, tokensToResponse(tokens))
}

// requestPasswordReset handles POST /auth/password-reset/request. It ALWAYS
// returns 200 for a well-formed request, regardless of whether the account
// exists (anti-enumeration, PRD §6.1). A malformed body is still a 400 — that
// reveals nothing about account existence.
func (h *Handler) requestPasswordReset(c *gin.Context) {
	var req passwordResetRequestRequest
	if aerr := validate.BindJSON(c, &req); aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	// Service always returns nil here; ignoring it is intentional.
	_ = h.svc.RequestPasswordReset(c.Request.Context(), req.Email)
	httpx.OK(c, gin.H{"status": "ok"})
}

// confirmPasswordReset handles POST /auth/password-reset/confirm.
func (h *Handler) confirmPasswordReset(c *gin.Context) {
	var req passwordResetConfirmRequest
	if aerr := validate.BindJSON(c, &req); aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	if aerr := h.svc.ConfirmPasswordReset(c.Request.Context(), req.Token, req.NewPassword); aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	httpx.OK(c, gin.H{"status": "ok"})
}

// verifyEmail handles POST /auth/verify-email. The token in the body identifies
// and authorizes the account, so no bearer is required. A bad/expired token is a
// 401; success is a plain 200.
func (h *Handler) verifyEmail(c *gin.Context) {
	var req verifyEmailRequest
	if aerr := validate.BindJSON(c, &req); aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	if aerr := h.svc.VerifyEmail(c.Request.Context(), req.Token); aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	httpx.OK(c, gin.H{"verified": true})
}

// resendVerification handles POST /auth/verify-email/resend. Like the
// password-reset request it ALWAYS returns 200 for a well-formed body
// (anti-enumeration); the service decides whether to actually send.
func (h *Handler) resendVerification(c *gin.Context) {
	var req resendVerificationRequest
	if aerr := validate.BindJSON(c, &req); aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	// Service always returns nil here; ignoring it is intentional.
	_ = h.svc.ResendVerification(c.Request.Context(), req.Email)
	httpx.OK(c, gin.H{"status": "ok"})
}

// deleteAccount handles DELETE /auth/account (bearer-authenticated). The user
// id comes from the validated access token via the Auth middleware.
func (h *Handler) deleteAccount(c *gin.Context) {
	userID, err := uuid.Parse(middleware.UserID(c))
	if err != nil {
		// Auth middleware guarantees a uid; a bad one means a malformed session.
		httpx.Fail(c, apperror.Unauthorized("invalid session"))
		return
	}
	if aerr := h.svc.DeleteAccount(c.Request.Context(), userID); aerr != nil {
		httpx.Fail(c, aerr)
		return
	}
	httpx.OK(c, gin.H{"deleted": true})
}
