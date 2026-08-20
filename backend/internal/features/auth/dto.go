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

// authTokensResponse is the contract's AuthTokens schema — returned by
// register, login, and refresh.
type authTokensResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

// tokensToResponse maps the service result to the wire shape.
func tokensToResponse(t Tokens) authTokensResponse {
	return authTokensResponse{AccessToken: t.Access, RefreshToken: t.Refresh}
}
