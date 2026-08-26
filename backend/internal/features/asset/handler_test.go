package asset

import (
	"bytes"
	"encoding/json"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	platformauth "github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/storage"
)

// Handler tests drive POST /assets through a real gin engine with httptest,
// exercising the Auth middleware, multipart parsing, the byte cap, and the
// contract-shaped JSON. They run on the mock repo + in-memory store — no external
// dependencies. Tokens are minted directly from a JWT manager (this feature
// doesn't issue them). Shared image/logger helpers live in service_test.go.

func newTestHandler(cfg config.AssetConfig) (*gin.Engine, *platformauth.Manager) {
	gin.SetMode(gin.TestMode)
	mgr := platformauth.NewManager("test-access-secret", "test-refresh-secret", 15*time.Minute, time.Hour)
	h := New(Deps{
		DB:     nil,
		Config: &config.Config{Env: "development", UseMockData: true, Asset: cfg},
		Logger: discardLogger(),
		Store:  storage.NewMemory(),
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

func tokenFor(t *testing.T, mgr *platformauth.Manager, userID uuid.UUID) string {
	t.Helper()
	tok, err := mgr.GenerateAccess(userID.String(), platformauth.RoleUser)
	if err != nil {
		t.Fatalf("GenerateAccess: %v", err)
	}
	return tok
}

// uploadReq builds a multipart POST /v1/assets carrying content under the given
// form field, with an optional bearer token.
func uploadReq(t *testing.T, field, filename string, content []byte, bearer string) *http.Request {
	t.Helper()
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	fw, err := w.CreateFormFile(field, filename)
	if err != nil {
		t.Fatalf("CreateFormFile: %v", err)
	}
	if _, err := fw.Write(content); err != nil {
		t.Fatalf("write form file: %v", err)
	}
	if err := w.Close(); err != nil {
		t.Fatalf("close multipart writer: %v", err)
	}
	req := httptest.NewRequest(http.MethodPost, "/v1/assets", &buf)
	req.Header.Set("Content-Type", w.FormDataContentType())
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	return req
}

func serve(engine *gin.Engine, req *http.Request) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	engine.ServeHTTP(rec, req)
	return rec
}

func TestUploadHandlerRequiresAuth(t *testing.T) {
	engine, _ := newTestHandler(defaultAssetCfg())
	req := uploadReq(t, "file", "logo.png", makePNG(t, 256, 256), "") // no bearer
	if rec := serve(engine, req); rec.Code != http.StatusUnauthorized {
		t.Fatalf("unauthenticated upload: want 401, got %d (%s)", rec.Code, rec.Body.String())
	}
}

func TestUploadHandlerValidPNG(t *testing.T) {
	engine, mgr := newTestHandler(defaultAssetCfg())
	token := tokenFor(t, mgr, uuid.New())

	rec := serve(engine, uploadReq(t, "file", "logo.png", makePNG(t, 256, 256), token))
	if rec.Code != http.StatusCreated {
		t.Fatalf("valid upload: want 201, got %d (%s)", rec.Code, rec.Body.String())
	}

	var resp assetResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode assetResponse: %v (body=%s)", err, rec.Body.String())
	}
	if resp.ID == uuid.Nil {
		t.Fatal("response id: want a uuid, got nil")
	}
	if resp.Width != 256 || resp.Height != 256 {
		t.Fatalf("response dimensions: want 256x256, got %dx%d", resp.Width, resp.Height)
	}
	if resp.MimeType != "image/png" {
		t.Fatalf("response mime: want image/png, got %s", resp.MimeType)
	}
	if resp.CreatedAt.IsZero() {
		t.Fatal("response created_at: want a timestamp, got zero")
	}
	// storage_ref / owner must never be disclosed on the wire.
	if bytes.Contains(rec.Body.Bytes(), []byte("storage_ref")) || bytes.Contains(rec.Body.Bytes(), []byte("owner")) {
		t.Fatalf("response leaks internal fields: %s", rec.Body.String())
	}
}

func TestUploadHandlerRejectsNonImage(t *testing.T) {
	engine, mgr := newTestHandler(defaultAssetCfg())
	token := tokenFor(t, mgr, uuid.New())

	rec := serve(engine, uploadReq(t, "file", "notes.txt", []byte("plain text, not an image at all"), token))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("non-image upload: want 400, got %d (%s)", rec.Code, rec.Body.String())
	}
}

func TestUploadHandlerRejectsOversize(t *testing.T) {
	cfg := defaultAssetCfg()
	cfg.MaxBytes = 512 // smaller than any real PNG
	engine, mgr := newTestHandler(cfg)
	token := tokenFor(t, mgr, uuid.New())

	rec := serve(engine, uploadReq(t, "file", "big.png", makePNG(t, 256, 256), token))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("oversize upload: want 400, got %d (%s)", rec.Code, rec.Body.String())
	}
}

// A request with no "file" part (wrong field name) is a client error, not a 500.
func TestUploadHandlerRejectsMissingFile(t *testing.T) {
	engine, mgr := newTestHandler(defaultAssetCfg())
	token := tokenFor(t, mgr, uuid.New())

	rec := serve(engine, uploadReq(t, "image", "logo.png", makePNG(t, 256, 256), token)) // wrong field
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("missing file part: want 400, got %d (%s)", rec.Code, rec.Body.String())
	}
}
