package generation

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/hashtag"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/moderation"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/quota"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider/stub"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/queue"
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

	// Minimal module: only need routing and middleware for the gate test.
	mod := New(Deps{
		Config:     &config.Config{UseMockData: true},
		Logger:     slog.Default(),
		TextChain:  provider.NewTextChain(30*time.Second, nil, stub.NewText()),
		Moderation: moderation.NewPermissiveChecker(),
		Quota:      quota.NewService(quota.NewMockRepository(), quota.Limits{TextDaily: 50, ImageDaily: 20}, slog.Default()),
		Hashtag:    hashtag.NewBank(),
		Queue:      queue.NewInProc(3, slog.Default()),
	})
	mod.Handler.RegisterRoutes(engine.Group("/v1"), mw)

	const uid = "11111111-1111-1111-1111-111111111111"
	call := func(bearer string) *httptest.ResponseRecorder {
		body := strings.NewReader(`{"input_text":"test","input_lang":"en","platform":"instagram"}`)
		req := httptest.NewRequest(http.MethodPost, "/v1/generate/text", body)
		req.Header.Set("Content-Type", "application/json")
		if bearer != "" {
			req.Header.Set("Authorization", "Bearer "+bearer)
		}
		rec := httptest.NewRecorder()
		engine.ServeHTTP(rec, req)
		return rec
	}

	// Unverified access token → 403 email_not_verified, before the handler.
	unverified, err := mgr.GenerateAccess(uid, auth.RoleUser, false)
	if err != nil {
		t.Fatalf("mint unverified token: %v", err)
	}
	rec := call(unverified)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("unverified: want 403, got %d (%s)", rec.Code, rec.Body.String())
	}
	var errBody struct {
		ErrorCode string `json:"error_code"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &errBody); err != nil {
		t.Fatalf("decode error body: %v", err)
	}
	if errBody.ErrorCode != string(apperror.CodeEmailNotVerified) {
		t.Fatalf("unverified: want error_code=%q, got %q", apperror.CodeEmailNotVerified, errBody.ErrorCode)
	}

	// Verified token: gate allows through; stub provider returns generated content -> 200.
	verified, err := mgr.GenerateAccess(uid, auth.RoleUser, true)
	if err != nil {
		t.Fatalf("mint verified token: %v", err)
	}
	if rec := call(verified); rec.Code != http.StatusOK {
		t.Fatalf("verified: want 200 (past the gate), got %d (%s)", rec.Code, rec.Body.String())
	}

	// No token at all -> 401 from Auth.
	if rec := call(""); rec.Code != http.StatusUnauthorized {
		t.Fatalf("no token: want 401, got %d", rec.Code)
	}
}
