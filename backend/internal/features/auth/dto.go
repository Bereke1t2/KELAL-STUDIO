package auth

// DTOs mirror openapi.yaml exactly — field names are the JSON contract the
// mobile client is generated against, so renaming one is a breaking change.
// Validation rules (`binding` tags) match the spec's constraints; validate.
// BindJSON turns any violation into a contract-shaped validation_error.

// registerRequest is the body of POST /auth/register.
type registerRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8"`
}

// loginRequest is the body of POST /auth/login. Password has no min here: the
// spec omits it, and rejecting a short password would leak that the stored one
// differs — login stays a single generic failure regardless.
type loginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

// refreshRequest is the body of POST /auth/refresh.
type refreshRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

// passwordResetRequestRequest is the body of POST /auth/password-reset/request.
type passwordResetRequestRequest struct {
	Email string `json:"email" binding:"required,email"`
}

// passwordResetConfirmRequest is the body of POST /auth/password-reset/confirm.
type passwordResetConfirmRequest struct {
	Token       string `json:"token" binding:"required"`
	NewPassword string `json:"new_password" binding:"required,min=8"`
}

// verifyEmailRequest is the body of POST /auth/verify-email. The token itself
// authenticates the request (it's minted for one user), so no bearer is needed.
type verifyEmailRequest struct {
	Token string `json:"token" binding:"required"`
}

// resendVerificationRequest is the body of POST /auth/verify-email/resend.
type resendVerificationRequest struct {
	Email string `json:"email" binding:"required,email"`
}

// registerResponse is the body of POST /auth/register (PRD §11). Registration no
// longer returns tokens — it returns the new user's id and whether a verification
// email went out.
type registerResponse struct {
	UserID           string `json:"user_id"`
	VerificationSent bool   `json:"verification_sent"`
}

// registerResultToResponse maps the service result to the wire shape. The two
// structs share field names and types, so a direct conversion suffices.
func registerResultToResponse(r RegisterResult) registerResponse {
	return registerResponse(r)
}

// authTokensResponse is the contract's AuthTokens schema — returned by login and
// refresh (no longer by register, see registerResponse).
type authTokensResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

// tokensToResponse maps the service result to the wire shape.
func tokensToResponse(t Tokens) authTokensResponse {
	return authTokensResponse{AccessToken: t.Access, RefreshToken: t.Refresh}
}
