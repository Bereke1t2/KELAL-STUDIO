package auth

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// Handler tests drive the feature through a real gin engine with httptest —
// exercising binding, the auth middleware, and the contract-shaped JSON. Like
// the service tests, they run on the mock repo with no external dependencies.

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

func TestHandlerRegisterAndLogin(t *testing.T) {
	engine, _ := newTestHandler()

	// Register returns 200 + AuthTokens (contract shape).
	rec := do(engine, http.MethodPost, "/v1/auth/register",
		gin.H{"email": "user@example.com", "password": "password123"}, "")
	if rec.Code != http.StatusOK {
		t.Fatalf("register: want 200, got %d (%s)", rec.Code, rec.Body.String())
	}
	tokens := decodeTokens(t, rec)
	if tokens.AccessToken == "" || tokens.RefreshToken == "" {
		t.Fatalf("register: expected populated AuthTokens, got %+v", tokens)
	}

	// A short password fails validation with 400.
	rec = do(engine, http.MethodPost, "/v1/auth/register",
		gin.H{"email": "shorty@example.com", "password": "short"}, "")
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("register short password: want 400, got %d", rec.Code)
	}

	// Login with the registered credentials succeeds.
	rec = do(engine, http.MethodPost, "/v1/auth/login",
		gin.H{"email": "user@example.com", "password": "password123"}, "")
	if rec.Code != http.StatusOK {
		t.Fatalf("login: want 200, got %d (%s)", rec.Code, rec.Body.String())
	}

	// Wrong password is a 401.
	rec = do(engine, http.MethodPost, "/v1/auth/login",
		gin.H{"email": "user@example.com", "password": "wrong"}, "")
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("login wrong password: want 401, got %d", rec.Code)
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

	// Register to get a valid access token, then delete succeeds.
	rec = do(engine, http.MethodPost, "/v1/auth/register",
		gin.H{"email": "user@example.com", "password": "password123"}, "")
	tokens := decodeTokens(t, rec)

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
