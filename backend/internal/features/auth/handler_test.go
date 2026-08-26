package auth

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// Handler tests drive the feature through a real gin engine with httptest —
// exercising binding, the auth middleware, and the contract-shaped JSON. Like
// the service tests, they run on the mock repo with no external dependencies
// (module.New supplies a dev LogSender when Deps.Mailer is nil).

func newTestHandler() (*gin.Engine, *auth.Manager) {
	gin.SetMode(gin.TestMode)
	mgr := testManager()
	h := New(Deps{
		DB:     nil,
		JWT:    mgr,
		Config: &config.Config{Env: "development", UseMockData: true},
		Logger: discardLogger(),
	})
	mw := middleware.Set{
		AuthRequired:  middleware.Auth(mgr),
		AdminOnly:     func(c *gin.Context) { c.Next() },
		UserRateLimit: func(c *gin.Context) { c.Next() },
	}
	engine := gin.New()
	v1 := engine.Group("/v1")
	h.RegisterRoutes(v1, mw)
	return engine, mgr
}

// do issues a request with an optional JSON body and bearer token.
func do(engine *gin.Engine, method, path string, body any, bearer string) *httptest.ResponseRecorder {
	var buf bytes.Buffer
	if body != nil {
		_ = json.NewEncoder(&buf).Encode(body)
	}
	req := httptest.NewRequest(method, path, &buf)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	rec := httptest.NewRecorder()
	engine.ServeHTTP(rec, req)
	return rec
}

func decodeTokens(t *testing.T, rec *httptest.ResponseRecorder) authTokensResponse {
	t.Helper()
	var resp authTokensResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode AuthTokens: %v (body=%s)", err, rec.Body.String())
	}
	return resp
}

func decodeRegister(t *testing.T, rec *httptest.ResponseRecorder) registerResponse {
	t.Helper()
	var resp registerResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode RegisterResult: %v (body=%s)", err, rec.Body.String())
	}
	return resp
}

// login registers is done separately; this logs in and returns the token pair.
func login(t *testing.T, engine *gin.Engine, email, password string) authTokensResponse {
	t.Helper()
	rec := do(engine, http.MethodPost, "/v1/auth/login",
		gin.H{"email": email, "password": password}, "")
	if rec.Code != http.StatusOK {
		t.Fatalf("login: want 200, got %d (%s)", rec.Code, rec.Body.String())
	}
	return decodeTokens(t, rec)
}

func TestHandlerRegisterAndLogin(t *testing.T) {
	engine, _ := newTestHandler()

	// Register returns 201 + {user_id, verification_sent} (PRD §11 shape); it no
	// longer establishes a session.
	rec := do(engine, http.MethodPost, "/v1/auth/register",
		gin.H{"email": "user@example.com", "password": "password123"}, "")
	if rec.Code != http.StatusCreated {
		t.Fatalf("register: want 201, got %d (%s)", rec.Code, rec.Body.String())
	}
	reg := decodeRegister(t, rec)
	if reg.UserID == "" {
		t.Fatalf("register: expected a user_id, got %+v", reg)
	}
	if !reg.VerificationSent {
		t.Fatalf("register: expected verification_sent=true, got %+v", reg)
	}

	// A short password fails validation with 400.
	rec = do(engine, http.MethodPost, "/v1/auth/register",
		gin.H{"email": "shorty@example.com", "password": "short"}, "")
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("register short password: want 400, got %d", rec.Code)
	}

	// Login with the registered credentials succeeds and returns AuthTokens.
	tokens := login(t, engine, "user@example.com", "password123")
	if tokens.AccessToken == "" || tokens.RefreshToken == "" {
		t.Fatalf("login: expected populated AuthTokens, got %+v", tokens)
	}

	// Wrong password is a 401.
	rec = do(engine, http.MethodPost, "/v1/auth/login",
		gin.H{"email": "user@example.com", "password": "wrong"}, "")
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("login wrong password: want 401, got %d", rec.Code)
	}
}

func TestHandlerVerifyEmail(t *testing.T) {
	engine, mgr := newTestHandler()

	rec := do(engine, http.MethodPost, "/v1/auth/register",
		gin.H{"email": "user@example.com", "password": "password123"}, "")
	reg := decodeRegister(t, rec)

	// Mint the same verification token the registration email carries.
	token, err := mgr.GenerateVerify(reg.UserID, time.Hour)
	if err != nil {
		t.Fatalf("GenerateVerify: %v", err)
	}
	rec = do(engine, http.MethodPost, "/v1/auth/verify-email", gin.H{"token": token}, "")
	if rec.Code != http.StatusOK {
		t.Fatalf("verify-email: want 200, got %d (%s)", rec.Code, rec.Body.String())
	}

	// A malformed body is a 400 (missing token).
	rec = do(engine, http.MethodPost, "/v1/auth/verify-email", gin.H{}, "")
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("verify-email missing token: want 400, got %d", rec.Code)
	}
	// A bad token is a 401.
	rec = do(engine, http.MethodPost, "/v1/auth/verify-email", gin.H{"token": "nope"}, "")
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("verify-email bad token: want 401, got %d", rec.Code)
	}

	// Resend always returns 200 for a well-formed body, even for an unknown email.
	rec = do(engine, http.MethodPost, "/v1/auth/verify-email/resend",
		gin.H{"email": "ghost@example.com"}, "")
	if rec.Code != http.StatusOK {
		t.Fatalf("verify-email/resend: want 200, got %d", rec.Code)
	}
}

func TestHandlerPasswordResetRequestAlways200(t *testing.T) {
	engine, _ := newTestHandler()
	// Unknown email must still return 200 (anti-enumeration).
	rec := do(engine, http.MethodPost, "/v1/auth/password-reset/request",
		gin.H{"email": "ghost@example.com"}, "")
	if rec.Code != http.StatusOK {
		t.Fatalf("password reset request: want 200, got %d", rec.Code)
	}
}

func TestHandlerDeleteAccountRequiresAuth(t *testing.T) {
	engine, _ := newTestHandler()

	// No bearer token → 401 from the Auth middleware.
	rec := do(engine, http.MethodDelete, "/v1/auth/account", nil, "")
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("delete account unauthenticated: want 401, got %d", rec.Code)
	}

	// Register then log in for a valid access token (register no longer returns one).
	do(engine, http.MethodPost, "/v1/auth/register",
		gin.H{"email": "user@example.com", "password": "password123"}, "")
	tokens := login(t, engine, "user@example.com", "password123")

	rec = do(engine, http.MethodDelete, "/v1/auth/account", nil, tokens.AccessToken)
	if rec.Code != http.StatusOK {
		t.Fatalf("delete account: want 200, got %d (%s)", rec.Code, rec.Body.String())
	}
}

// mustParseUUID is a shared test helper (used across the auth test files).
func mustParseUUID(t *testing.T, s string) uuid.UUID {
	t.Helper()
	id, err := uuid.Parse(s)
	if err != nil {
		t.Fatalf("parse uuid %q: %v", s, err)
	}
	return id
}
