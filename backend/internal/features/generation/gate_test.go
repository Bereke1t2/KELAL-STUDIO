package generation

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// The generation surface is gated on a verified email (PRD §6.1). This wires the
// real Auth + EmailVerifiedRequired middleware around the stub handler and checks
// the gate fires BEFORE the handler runs — minting verified vs unverified access
// tokens rather than going through the whole auth feature.
func TestGenerateTextRequiresVerifiedEmail(t *testing.T) {
	gin.SetMode(gin.TestMode)
	mgr := auth.NewManager("test-access", "test-refresh", 15*time.Minute, time.Hour)
	mw := middleware.Set{
		AuthRequired:  middleware.Auth(mgr),
		AdminOnly:     func(c *gin.Context) { c.Next() },
		UserRateLimit: func(c *gin.Context) { c.Next() },
		EmailVerified: middleware.EmailVerifiedRequired(),
	}
	engine := gin.New()
	// Only the middleware gate is under test here, so a minimal module suffices:
	// an empty request body fails binding (400) before the service — and its nil
	// provider/quota deps — is ever reached. Config must be non-nil (New reads
	// UseMockData) and a nil DB selects the in-memory repository.
	mod := New(Deps{Config: &config.Config{}})
	mod.Handler.RegisterRoutes(engine.Group("/v1"), mw)

	const uid = "11111111-1111-1111-1111-111111111111"
	call := func(bearer string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodPost, "/v1/generate/text", nil)
		if bearer != "" {
			req.Header.Set("Authorization", "Bearer "+bearer)
		}
		rec := httptest.NewRecorder()
		engine.ServeHTTP(rec, req)
		return rec
	}

	// Unverified access token → 403 email_not_verified, before the stub handler.
	unverified, err := mgr.GenerateAccess(uid, auth.RoleUser, false)
	if err != nil {
		t.Fatalf("mint unverified token: %v", err)
	}
	rec := call(unverified)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("unverified: want 403, got %d (%s)", rec.Code, rec.Body.String())
	}
	var body struct {
		ErrorCode string `json:"error_code"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode error body: %v", err)
	}
	if body.ErrorCode != string(apperror.CodeEmailNotVerified) {
		t.Fatalf("unverified: want error_code=%q, got %q", apperror.CodeEmailNotVerified, body.ErrorCode)
	}

	// Verified token passes the gate and reaches the handler; the empty body then
	// fails request validation (400 validation_error) — proving the gate let it
	// through instead of short-circuiting with 403 email_not_verified.
	verified, err := mgr.GenerateAccess(uid, auth.RoleUser, true)
	if err != nil {
		t.Fatalf("mint verified token: %v", err)
	}
	if rec := call(verified); rec.Code != http.StatusBadRequest {
		t.Fatalf("verified: want 400 (past the gate, empty body fails validation), got %d (%s)", rec.Code, rec.Body.String())
	}

	// No token at all → 401 from Auth; the gate is never reached.
	if rec := call(""); rec.Code != http.StatusUnauthorized {
		t.Fatalf("no token: want 401, got %d", rec.Code)
	}
}
