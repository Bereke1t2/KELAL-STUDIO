// Package apperror is the backend's typed error taxonomy — the Go analogue of
// the mobile app's sealed `Failure` type. Errors are VALUES that are returned,
// never panicked across a package boundary, and they carry everything the HTTP
// layer needs to render a contract-shaped response (openapi.yaml ErrorResponse):
// an error_code the client branches on, an already-localized message, the HTTP
// status, and — for quota_exceeded — the reset time.
//
// The single rule this package exists to enforce: every failure that crosses a
// public API surface is an *apperror.Error, so the delivery layer can turn it
// into a predictable JSON body without a type switch per feature.
package apperror

import (
	"errors"
	"fmt"
	"net/http"
	"time"
)

// Code is the machine-readable error_code the client branches on.
type Code string

const (
	// ── Contract taxonomy ──────────────────────────────────────────────────
	// These five are the closed enum in openapi.yaml (ErrorResponse.error_code)
	// — the codes the mobile client is generated against. Keep the string
	// values EXACT; renaming one is a breaking client change.

	// CodeQuotaExceeded is returned when the per-user daily cap was hit
	// (PRD §6.14). It carries ResetsAt so the client can say when it lifts.
	CodeQuotaExceeded Code = "quota_exceeded"
	// CodeProviderTimeout is returned when every provider in the failover chain
	// timed out or failed (PRD §10.1).
	CodeProviderTimeout Code = "provider_timeout"
	// CodeModerationRefused is returned when input/output was blocked by the
	// moderation service (PRD §6.4). The message is a plain-language reason,
	// never a raw classifier code.
	CodeModerationRefused Code = "moderation_refused"
	// CodeMalformedOutput is returned when a provider returned something we
	// couldn't parse into the contract shape (PRD §10.1 defensive parsing).
	CodeMalformedOutput Code = "malformed_output"
	// CodeValidationError is returned when the request failed validation (bad
	// field, wrong enum).
	CodeValidationError Code = "validation_error"
)

// Infrastructure / transport codes. FLAG (see docs/OPEN_QUESTIONS.md): these are
// NOT in the contract's closed enum. They accompany the standard HTTP statuses
// 401/403/404/409/429/500/501 — a status genuinely needs a code, and inventing
// "validation_error" for an auth failure would be a lie. Either the contract
// enum is widened to include them, or the client treats error_code as an open
// string and branches only on the five contract codes above. Until that's
// decided, the backend emits these.
const (
	CodeUnauthorized     Code = "unauthorized"
	CodeForbidden        Code = "forbidden"
	CodeEmailNotVerified Code = "email_not_verified"
	CodeNotFound         Code = "not_found"
	CodeConflict         Code = "conflict"
	CodeRateLimited      Code = "rate_limited"
	CodeAccountLocked    Code = "account_locked"
	CodeInternal         Code = "internal"
	CodeNotImplemented   Code = "not_implemented"
)

// Error is the one error type that crosses feature boundaries.
type Error struct {
	Code       Code
	Message    string     // plain-language, already localized where applicable (PRD §6.4)
	HTTPStatus int        // the status the delivery layer should write
	ResetsAt   *time.Time // set only for CodeQuotaExceeded
	cause      error      // optional wrapped cause for server logs; NEVER serialized
}

func (e *Error) Error() string {
	if e.cause != nil {
		return fmt.Sprintf("%s: %s: %v", e.Code, e.Message, e.cause)
	}
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

// Unwrap exposes the wrapped cause to errors.Is / errors.As.
func (e *Error) Unwrap() error { return e.cause }

// WithCause attaches an underlying error for logging. The cause is never sent
// to the client — only recorded server-side.
func (e *Error) WithCause(cause error) *Error {
	e.cause = cause
	return e
}

// Response is the wire shape (openapi.yaml ErrorResponse). resets_at is omitted
// unless present, matching "Present only for quota_exceeded".
type Response struct {
	ErrorCode string     `json:"error_code"`
	Message   string     `json:"message"`
	ResetsAt  *time.Time `json:"resets_at,omitempty"`
}

// Response renders the error into its JSON body shape.
func (e *Error) Response() Response {
	return Response{
		ErrorCode: string(e.Code),
		Message:   e.Message,
		ResetsAt:  e.ResetsAt,
	}
}

// From coerces any error into an *Error. If it already is one (including
// wrapped), it's returned as-is; otherwise it becomes an opaque internal error
// whose real cause is kept for logs but hidden from the client.
func From(err error) *Error {
	if err == nil {
		return nil
	}
	var ae *Error
	if errors.As(err, &ae) {
		return ae
	}
	return Internal(err)
}

// ── Constructors ─────────────────────────────────────────────────────────────

// Validation builds a 400 validation_error with a client-facing message.
func Validation(message string) *Error {
	return &Error{Code: CodeValidationError, Message: message, HTTPStatus: http.StatusBadRequest}
}

// Unauthorized builds a 401. Keep the message generic for auth failures so it
// can't be used to probe (PRD §6.1).
func Unauthorized(message string) *Error {
	return &Error{Code: CodeUnauthorized, Message: message, HTTPStatus: http.StatusUnauthorized}
}

// Forbidden builds a 403 (authenticated but not allowed, e.g. non-admin).
func Forbidden(message string) *Error {
	return &Error{Code: CodeForbidden, Message: message, HTTPStatus: http.StatusForbidden}
}

// EmailNotVerified builds a 403 — the caller is authenticated but hasn't verified
// their email, which gates content generation (PRD §6.1). Distinct code from
// Forbidden so the client can prompt "verify your email" rather than "access
// denied".
func EmailNotVerified(message string) *Error {
	return &Error{Code: CodeEmailNotVerified, Message: message, HTTPStatus: http.StatusForbidden}
}

// NotFound builds a 404.
func NotFound(message string) *Error {
	return &Error{Code: CodeNotFound, Message: message, HTTPStatus: http.StatusNotFound}
}

// Conflict builds a 409 (e.g. email already registered).
func Conflict(message string) *Error {
	return &Error{Code: CodeConflict, Message: message, HTTPStatus: http.StatusConflict}
}

// QuotaExceeded builds a 429 carrying the reset time (PRD §6.14).
func QuotaExceeded(message string, resetsAt time.Time) *Error {
	return &Error{Code: CodeQuotaExceeded, Message: message, HTTPStatus: http.StatusTooManyRequests, ResetsAt: &resetsAt}
}

// RateLimited builds a 429 for gateway rate limiting (distinct from quota).
func RateLimited(message string) *Error {
	return &Error{Code: CodeRateLimited, Message: message, HTTPStatus: http.StatusTooManyRequests}
}

// AccountLocked builds a 429 — the account is temporarily locked after too many
// failed logins (PRD §6.1 lockout policy). Distinct code from RateLimited so the
// client can explain it's the account, not the request rate, that's throttled.
func AccountLocked(message string) *Error {
	return &Error{Code: CodeAccountLocked, Message: message, HTTPStatus: http.StatusTooManyRequests}
}

// ProviderTimeout builds a 504 — the whole provider failover chain failed.
func ProviderTimeout(message string) *Error {
	return &Error{Code: CodeProviderTimeout, Message: message, HTTPStatus: http.StatusGatewayTimeout}
}

// ModerationRefused builds a 422 with a plain-language reason (PRD §6.4).
func ModerationRefused(message string) *Error {
	return &Error{Code: CodeModerationRefused, Message: message, HTTPStatus: http.StatusUnprocessableEntity}
}

// MalformedOutput builds a 502 — a provider returned unparseable output.
func MalformedOutput(message string) *Error {
	return &Error{Code: CodeMalformedOutput, Message: message, HTTPStatus: http.StatusBadGateway}
}

// Internal builds an opaque 500. The cause is logged, never serialized.
func Internal(cause error) *Error {
	return &Error{
		Code:       CodeInternal,
		Message:    "An unexpected error occurred.",
		HTTPStatus: http.StatusInternalServerError,
		cause:      cause,
	}
}

// NotImplemented builds a 501 in the taxonomy shape. Every feature stub returns
// this so the app boots and the mobile team can integrate against a real error
// body today (see docs/FEATURE_OWNERSHIP.md).
func NotImplemented(feature string) *Error {
	return &Error{
		Code:       CodeNotImplemented,
		Message:    fmt.Sprintf("%s is not implemented yet.", feature),
		HTTPStatus: http.StatusNotImplemented,
	}
}
