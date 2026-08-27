package admin

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
	platformauth "github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
)

// Handler tests drive the feature through a real gin engine with httptest,
// exercising the REAL auth + admin-role middleware (not the pass-throughs the
// other features' tests use) — role gating is the defining property of this
// surface, so it's tested end to end. The handler is built over a seeded mock so
// mutating happy paths can assert the audit row was written over HTTP; New(Deps)
// is exercised by cmd/api wiring. Tokens are minted directly from a JWT manager.

// newTestHandler wires an admin Handler over a seeded mock behind real Auth +
// AdminOnly middleware. It returns the mock so tests can seed rows and inspect
// the audit log.
func newTestHandler() (*gin.Engine, *platformauth.Manager, *mockRepository) {
	gin.SetMode(gin.TestMode)
	mgr := platformauth.NewManager("test-access-secret", "test-refresh-secret", 15*time.Minute, time.Hour)
	repo := newMockRepository()
	h := NewHandler(NewService(repo, discardLogger()))
	mw := middleware.Set{
		AuthRequired:  middleware.Auth(mgr),
		AdminOnly:     middleware.AdminOnly(),
		UserRateLimit: func(c *gin.Context) { c.Next() },
	}
	engine := gin.New()
	v1 := engine.Group("/v1")
	h.RegisterRoutes(v1, mw)
	return engine, mgr, repo
}

func adminToken(t *testing.T, mgr *platformauth.Manager, adminID uuid.UUID) string {
	t.Helper()
	tok, err := mgr.GenerateAccess(adminID.String(), platformauth.RoleAdmin, true)
	if err != nil {
		t.Fatalf("GenerateAccess admin: %v", err)
	}
	return tok
}

func userToken(t *testing.T, mgr *platformauth.Manager, userID uuid.UUID) string {
	t.Helper()
	tok, err := mgr.GenerateAccess(userID.String(), platformauth.RoleUser, true)
	if err != nil {
		t.Fatalf("GenerateAccess user: %v", err)
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

// Without a token, every admin route is a 401 from the Auth middleware.
func TestHandlerRequiresAuth(t *testing.T) {
	engine, _, _ := newTestHandler()
	cases := []struct{ method, path string }{
		{http.MethodGet, "/v1/admin/usage"},
		{http.MethodGet, "/v1/admin/flags"},
		{http.MethodPost, "/v1/admin/flags/" + uuid.NewString() + "/review"},
		{http.MethodPut, "/v1/admin/users/" + uuid.NewString() + "/limits"},
	}
	for _, c := range cases {
		if rec := do(engine, c.method, c.path, nil, ""); rec.Code != http.StatusUnauthorized {
			t.Fatalf("%s %s unauthenticated: want 401, got %d", c.method, c.path, rec.Code)
		}
	}
}

// A valid but non-admin session is a 403 on every admin route (the AdminOnly
// gate), regardless of whether the target exists.
func TestHandlerRejectsNonAdmin(t *testing.T) {
	engine, mgr, _ := newTestHandler()
	token := userToken(t, mgr, uuid.New())
	cases := []struct {
		method, path string
		body         any
	}{
		{http.MethodGet, "/v1/admin/usage", nil},
		{http.MethodGet, "/v1/admin/flags", nil},
		{http.MethodPost, "/v1/admin/flags/" + uuid.NewString() + "/review", nil},
		{http.MethodPut, "/v1/admin/users/" + uuid.NewString() + "/limits", gin.H{"daily_text_quota": 1}},
	}
	for _, c := range cases {
		if rec := do(engine, c.method, c.path, c.body, token); rec.Code != http.StatusForbidden {
			t.Fatalf("%s %s as non-admin: want 403, got %d (%s)", c.method, c.path, rec.Code, rec.Body.String())
		}
	}
}

func TestHandlerUsage(t *testing.T) {
	engine, mgr, repo := newTestHandler()
	seedUser(repo)
	repo.generations = []models.GenerationRecord{{Type: models.GenerationText}}
	seedFlag(repo, false)

	rec := do(engine, http.MethodGet, "/v1/admin/usage", nil, adminToken(t, mgr, uuid.New()))
	if rec.Code != http.StatusOK {
		t.Fatalf("GET usage: want 200, got %d (%s)", rec.Code, rec.Body.String())
	}
	var resp usageResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode usage: %v (body=%s)", err, rec.Body.String())
	}
	if resp.TotalUsers != 1 || resp.TextGenerations != 1 || resp.TotalFlags != 1 || resp.PendingFlags != 1 {
		t.Fatalf("usage body wrong: %+v", resp)
	}
}

func TestHandlerListFlags(t *testing.T) {
	engine, mgr, repo := newTestHandler()
	seedFlag(repo, false)
	seedFlag(repo, true)
	token := adminToken(t, mgr, uuid.New())

	rec := do(engine, http.MethodGet, "/v1/admin/flags", nil, token)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET flags: want 200, got %d (%s)", rec.Code, rec.Body.String())
	}
	var resp flagsResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode flags: %v", err)
	}
	if len(resp.Flags) != 2 {
		t.Fatalf("GET flags: want 2, got %d", len(resp.Flags))
	}

	// ?status=pending narrows to unreviewed flags.
	rec = do(engine, http.MethodGet, "/v1/admin/flags?status=pending", nil, token)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET flags pending: want 200, got %d", rec.Code)
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &resp)
	if len(resp.Flags) != 1 || resp.Flags[0].ReviewedAt != nil {
		t.Fatalf("GET flags pending: want 1 unreviewed, got %+v", resp.Flags)
	}
}

func TestHandlerReviewFlag(t *testing.T) {
	engine, mgr, repo := newTestHandler()
	flag := seedFlag(repo, false)
	adminID := uuid.New()

	rec := do(engine, http.MethodPost, "/v1/admin/flags/"+flag.ID.String()+"/review", nil, adminToken(t, mgr, adminID))
	if rec.Code != http.StatusOK {
		t.Fatalf("review: want 200, got %d (%s)", rec.Code, rec.Body.String())
	}
	var resp flagResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode flag: %v", err)
	}
	if resp.ReviewedAt == nil || resp.ReviewedByAdminID == nil || *resp.ReviewedByAdminID != adminID {
		t.Fatalf("review: response not marked reviewed by caller: %+v", resp)
	}
	// The audited-mutation invariant, end to end.
	if len(repo.auditLogs) != 1 || repo.auditLogs[0].Action != auditActionReviewFlag {
		t.Fatalf("review: expected one flag.review audit row, got %+v", repo.auditLogs)
	}
}

func TestHandlerReviewUnknownFlagIs404(t *testing.T) {
	engine, mgr, _ := newTestHandler()
	rec := do(engine, http.MethodPost, "/v1/admin/flags/"+uuid.NewString()+"/review", nil, adminToken(t, mgr, uuid.New()))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("review unknown: want 404, got %d (%s)", rec.Code, rec.Body.String())
	}
}

func TestHandlerReviewBadIdIs400(t *testing.T) {
	engine, mgr, _ := newTestHandler()
	rec := do(engine, http.MethodPost, "/v1/admin/flags/not-a-uuid/review", nil, adminToken(t, mgr, uuid.New()))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("review bad id: want 400, got %d (%s)", rec.Code, rec.Body.String())
	}
}

func TestHandlerSetUserLimits(t *testing.T) {
	engine, mgr, repo := newTestHandler()
	user := seedUser(repo)

	rec := do(engine, http.MethodPut, "/v1/admin/users/"+user.ID.String()+"/limits",
		gin.H{"daily_text_quota": 25, "daily_image_quota": 0}, adminToken(t, mgr, uuid.New()))
	if rec.Code != http.StatusOK {
		t.Fatalf("set limits: want 200, got %d (%s)", rec.Code, rec.Body.String())
	}
	var resp userLimitsResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode limits: %v", err)
	}
	if resp.DailyTextQuota == nil || *resp.DailyTextQuota != 25 {
		t.Fatalf("set limits: text quota not applied: %+v", resp)
	}
	if resp.DailyImageQuota == nil || *resp.DailyImageQuota != 0 {
		t.Fatalf("set limits: image quota (0) not applied: %+v", resp)
	}
	if len(repo.auditLogs) != 1 || repo.auditLogs[0].Action != auditActionSetUserLimits {
		t.Fatalf("set limits: expected one user.set_limits audit row, got %+v", repo.auditLogs)
	}
}

func TestHandlerSetUserLimitsUnknownIs404(t *testing.T) {
	engine, mgr, _ := newTestHandler()
	rec := do(engine, http.MethodPut, "/v1/admin/users/"+uuid.NewString()+"/limits",
		gin.H{"daily_text_quota": 5}, adminToken(t, mgr, uuid.New()))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("set limits unknown: want 404, got %d (%s)", rec.Code, rec.Body.String())
	}
}

func TestHandlerSetUserLimitsNegativeIs400(t *testing.T) {
	engine, mgr, repo := newTestHandler()
	user := seedUser(repo)
	rec := do(engine, http.MethodPut, "/v1/admin/users/"+user.ID.String()+"/limits",
		gin.H{"daily_text_quota": -3}, adminToken(t, mgr, uuid.New()))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("set limits negative: want 400, got %d (%s)", rec.Code, rec.Body.String())
	}
}
