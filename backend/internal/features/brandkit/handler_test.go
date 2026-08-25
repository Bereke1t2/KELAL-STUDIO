package brandkit

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	platformauth "github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// Handler tests drive the feature through a real gin engine with httptest —
// exercising the Auth middleware, path/body binding, ownership, and the
// contract-shaped JSON. Like the service tests they run on the mock repo with no
// external dependencies. Tokens are minted directly from a JWT manager (this
// feature doesn't issue them).

func newTestHandler() (*gin.Engine, *platformauth.Manager) {
	gin.SetMode(gin.TestMode)
	mgr := platformauth.NewManager("test-access-secret", "test-refresh-secret", 15*time.Minute, time.Hour)
	h := New(Deps{
		DB:     nil,
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

// tokenFor mints a valid access token for a user id. Brand-kit routes aren't
// gated on email verification (only generation is), so the verified flag is
// immaterial here — pass true for a representative fully-onboarded user.
func tokenFor(t *testing.T, mgr *platformauth.Manager, userID uuid.UUID) string {
	t.Helper()
	tok, err := mgr.GenerateAccess(userID.String(), platformauth.RoleUser, true)
	if err != nil {
		t.Fatalf("GenerateAccess: %v", err)
	}
	return tok
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

func decodeKit(t *testing.T, rec *httptest.ResponseRecorder) brandKitResponse {
	t.Helper()
	var resp brandKitResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode BrandKit: %v (body=%s)", err, rec.Body.String())
	}
	return resp
}

func TestHandlerRequiresAuth(t *testing.T) {
	engine, _ := newTestHandler()
	// No bearer token → 401 from the Auth middleware, on both verbs.
	if rec := do(engine, http.MethodGet, "/v1/brand-kits/"+uuid.NewString(), nil, ""); rec.Code != http.StatusUnauthorized {
		t.Fatalf("GET unauthenticated: want 401, got %d", rec.Code)
	}
	if rec := do(engine, http.MethodPut, "/v1/brand-kits/"+uuid.NewString(), gin.H{"brand_name": "x"}, ""); rec.Code != http.StatusUnauthorized {
		t.Fatalf("PUT unauthenticated: want 401, got %d", rec.Code)
	}
}

func TestHandlerPutThenGet(t *testing.T) {
	engine, mgr := newTestHandler()
	user := uuid.New()
	token := tokenFor(t, mgr, user)
	id := uuid.New()
	path := "/v1/brand-kits/" + id.String()

	// PUT creates and returns the kit (200, contract shape).
	rec := do(engine, http.MethodPut, path, gin.H{
		"brand_name":        "Kelal Studio",
		"primary_color_hex": "#0A0A0A",
	}, token)
	if rec.Code != http.StatusOK {
		t.Fatalf("PUT create: want 200, got %d (%s)", rec.Code, rec.Body.String())
	}
	created := decodeKit(t, rec)
	if created.ID != id || created.BrandName != "Kelal Studio" || created.UpdatedAt.IsZero() {
		t.Fatalf("PUT create: unexpected body %+v", created)
	}

	// GET returns the same kit.
	rec = do(engine, http.MethodGet, path, nil, token)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET: want 200, got %d (%s)", rec.Code, rec.Body.String())
	}
	if got := decodeKit(t, rec); got.ID != id || got.BrandName != "Kelal Studio" {
		t.Fatalf("GET: want the created kit, got %+v", got)
	}
}

// A kit is invisible and unwritable to anyone but its owner — both are 404.
func TestHandlerOthersKitIs404(t *testing.T) {
	engine, mgr := newTestHandler()
	alice, bob := uuid.New(), uuid.New()
	id := uuid.New()
	path := "/v1/brand-kits/" + id.String()

	if rec := do(engine, http.MethodPut, path, gin.H{"brand_name": "Alice Co"}, tokenFor(t, mgr, alice)); rec.Code != http.StatusOK {
		t.Fatalf("setup PUT as alice: want 200, got %d", rec.Code)
	}

	bobToken := tokenFor(t, mgr, bob)
	if rec := do(engine, http.MethodGet, path, nil, bobToken); rec.Code != http.StatusNotFound {
		t.Fatalf("GET other's kit: want 404, got %d", rec.Code)
	}
	if rec := do(engine, http.MethodPut, path, gin.H{"brand_name": "Bob hijack"}, bobToken); rec.Code != http.StatusNotFound {
		t.Fatalf("PUT over other's kit: want 404, got %d", rec.Code)
	}
}

func TestHandlerGetUnknownIs404(t *testing.T) {
	engine, mgr := newTestHandler()
	rec := do(engine, http.MethodGet, "/v1/brand-kits/"+uuid.NewString(), nil, tokenFor(t, mgr, uuid.New()))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("GET unknown: want 404, got %d", rec.Code)
	}
}

func TestHandlerRejectsMalformedInput(t *testing.T) {
	engine, mgr := newTestHandler()
	token := tokenFor(t, mgr, uuid.New())

	// A non-uuid path id is a 400, not a 404.
	if rec := do(engine, http.MethodGet, "/v1/brand-kits/not-a-uuid", nil, token); rec.Code != http.StatusBadRequest {
		t.Fatalf("GET bad id: want 400, got %d", rec.Code)
	}
	// A logo_asset_id that isn't a uuid fails binding with a 400.
	if rec := do(engine, http.MethodPut, "/v1/brand-kits/"+uuid.NewString(), gin.H{"logo_asset_id": "not-a-uuid"}, token); rec.Code != http.StatusBadRequest {
		t.Fatalf("PUT bad logo_asset_id: want 400, got %d (%s)", rec.Code, rec.Body.String())
	}
}
