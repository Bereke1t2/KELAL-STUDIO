package e2e_test

import (
	"bytes"
	"context"
	"encoding/json"
	"image"
	"image/png"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/api"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/admin"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/asset"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/auth"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/brandkit"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/generation"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/hashtag"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/moderation"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/quota"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/reminder"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apidocs"
	platformauth "github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/email"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/logger"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider/factory"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/queue"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/storage"
)

// RecordingMailer captures outbound emails for test assertions and token extraction.
type RecordingMailer struct {
	mu       sync.Mutex
	messages []email.Message
}

func (m *RecordingMailer) Send(_ context.Context, msg email.Message) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.messages = append(m.messages, msg)
	return nil
}

func (m *RecordingMailer) LastMessage() (email.Message, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if len(m.messages) == 0 {
		return email.Message{}, false
	}
	return m.messages[len(m.messages)-1], true
}

func (m *RecordingMailer) Clear() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.messages = nil
}

// e2eAdminRepository provides an in-memory admin.Repository that records and queries users, flags, and audit logs.
type e2eAdminRepository struct {
	mu          sync.RWMutex
	users       map[uuid.UUID]*models.User
	flags       map[uuid.UUID]*models.ModerationFlag
	generations []models.GenerationRecord
	auditLogs   []models.AdminAuditLog
}

func newE2EAdminRepository() *e2eAdminRepository {
	return &e2eAdminRepository{
		users: make(map[uuid.UUID]*models.User),
		flags: make(map[uuid.UUID]*models.ModerationFlag),
	}
}

func (r *e2eAdminRepository) AddUser(u *models.User) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.users[u.ID] = u
}

func (r *e2eAdminRepository) AddFlag(f *models.ModerationFlag) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.flags[f.ID] = f
}

func (r *e2eAdminRepository) UsageSummary(_ context.Context) (admin.UsageSummary, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	s := admin.UsageSummary{
		TotalUsers:       int64(len(r.users)),
		TotalGenerations: int64(len(r.generations)),
		TotalFlags:       int64(len(r.flags)),
	}
	for _, g := range r.generations {
		switch g.Type {
		case models.GenerationText:
			s.TextGenerations++
		case models.GenerationImage:
			s.ImageGenerations++
		case models.GenerationVideo:
			s.VideoGenerations++
		}
	}
	for _, f := range r.flags {
		if f.ReviewedAt == nil {
			s.PendingFlags++
		}
	}
	return s, nil
}

func (r *e2eAdminRepository) ListFlags(_ context.Context, onlyPending bool) ([]models.ModerationFlag, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	out := make([]models.ModerationFlag, 0, len(r.flags))
	for _, f := range r.flags {
		if onlyPending && f.ReviewedAt != nil {
			continue
		}
		out = append(out, *f)
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].CreatedAt.Equal(out[j].CreatedAt) {
			return out[i].ID.String() > out[j].ID.String()
		}
		return out[i].CreatedAt.After(out[j].CreatedAt)
	})
	return out, nil
}

func (r *e2eAdminRepository) FindFlagByID(_ context.Context, id uuid.UUID) (*models.ModerationFlag, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	f, ok := r.flags[id]
	if !ok {
		return nil, admin.ErrFlagNotFound
	}
	flagCopy := *f
	return &flagCopy, nil
}

func (r *e2eAdminRepository) ReviewFlag(_ context.Context, flag *models.ModerationFlag, audit *models.AdminAuditLog) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	stored, ok := r.flags[flag.ID]
	if !ok {
		return admin.ErrFlagNotFound
	}
	if stored.ReviewedAt != nil {
		return admin.ErrFlagAlreadyReviewed
	}
	r.flags[flag.ID] = flag
	if audit.ID == uuid.Nil {
		audit.ID = uuid.New()
	}
	r.auditLogs = append(r.auditLogs, *audit)
	return nil
}

func (r *e2eAdminRepository) FindUserByID(_ context.Context, id uuid.UUID) (*models.User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	u, ok := r.users[id]
	if !ok {
		return nil, admin.ErrUserNotFound
	}
	userCopy := *u
	return &userCopy, nil
}

func (r *e2eAdminRepository) SetUserLimits(_ context.Context, user *models.User, audit *models.AdminAuditLog) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	prev, ok := r.users[user.ID]
	if !ok {
		return admin.ErrUserNotFound
	}
	user.CreatedAt = prev.CreatedAt
	user.UpdatedAt = time.Now()
	r.users[user.ID] = user
	if audit.ID == uuid.Nil {
		audit.ID = uuid.New()
	}
	r.auditLogs = append(r.auditLogs, *audit)
	return nil
}

// testApp bundles the running server, HTTP client, and components.
type testApp struct {
	server    *httptest.Server
	client    *http.Client
	jwtMgr    *platformauth.Manager
	mailer    *RecordingMailer
	adminRepo *e2eAdminRepository
	queue     queue.Queue
	genMod    generation.Module
	cancelFn  context.CancelFunc
}

// setupE2EApp constructs the full application identically to cmd/api/main.go.
func setupE2EApp(t *testing.T) *testApp {
	t.Helper()
	gin.SetMode(gin.TestMode)

	cfg := &config.Config{
		Env:           "development",
		HTTPPort:      "8080",
		LogLevel:      "error",
		UseMockData:   true,
		PublicBaseURL: "http://localhost:8080",
		JWT: config.JWTConfig{
			AccessSecret:  "test-e2e-access-secret-32-bytes-long!",
			RefreshSecret: "test-e2e-refresh-secret-32-bytes-long!",
			AccessTTL:     15 * time.Minute,
			RefreshTTL:    24 * time.Hour,
		},
		Auth: config.AuthConfig{
			EmailVerificationTTL:   time.Hour,
			PasswordResetTTL:       time.Hour,
			LoginMaxFailedAttempts: 5,
			LoginLockoutDuration:   10 * time.Minute,
		},
		RateLim: config.RateLimitConfig{
			PerUserPerMinute: 1000,
			PerIPPerMinute:   1000,
		},
		Quota: config.QuotaConfig{
			TextDaily:  50,
			ImageDaily: 20,
		},
		Provider: config.ProviderConfig{
			TextOrder:  []string{"stub"},
			ImageOrder: []string{"stub"},
			Timeout:    5 * time.Second,
		},
		Queue: config.QueueConfig{
			Driver:           "inproc",
			VideoMaxAttempts: 3,
		},
		Asset: config.AssetConfig{
			StorageDir:   "./storage/assets_test",
			MaxBytes:     10 * 1024 * 1024,
			MaxDimension: 4096,
			MinDimension: 200,
		},
	}

	log := logger.New("error")
	jwtMgr := platformauth.NewManager(
		cfg.JWT.AccessSecret, cfg.JWT.RefreshSecret, cfg.JWT.AccessTTL, cfg.JWT.RefreshTTL,
	)
	assetStore := storage.NewMemory()
	recMailer := &RecordingMailer{}
	adminRepo := newE2EAdminRepository()

	engine, v1 := httpx.NewRouter(
		false,
		middleware.RequestID(),
		middleware.Logger(log),
		middleware.Recover(log),
		middleware.CORS(),
	)

	apidocs.Mount(engine, api.Spec)

	mw := middleware.Set{
		AuthRequired:  middleware.Auth(jwtMgr),
		AdminOnly:     middleware.AdminOnly(),
		UserRateLimit: func(c *gin.Context) { c.Next() },
		EmailVerified: middleware.EmailVerifiedRequired(),
	}

	// Wire feature slices
	auth.New(auth.Deps{DB: nil, JWT: jwtMgr, Config: cfg, Logger: log, Mailer: recMailer}).RegisterRoutes(v1, mw)
	brandkit.New(brandkit.Deps{DB: nil, Config: cfg, Logger: log}).RegisterRoutes(v1, mw)
	asset.New(asset.Deps{DB: nil, Config: cfg, Logger: log, Store: assetStore}).RegisterRoutes(v1, mw)

	textChain, err := factory.BuildTextChain(cfg.Provider.TextOrder, cfg.Provider.Timeout, nil, &cfg.Provider)
	if err != nil {
		t.Fatalf("build text chain: %v", err)
	}
	imageChain, err := factory.BuildImageChain(cfg.Provider.ImageOrder, cfg.Provider.Timeout, nil, &cfg.Provider)
	if err != nil {
		t.Fatalf("build image chain: %v", err)
	}
	videoChain, err := factory.BuildVideoChain(cfg.Provider.VideoOrder, cfg.Provider.Timeout, nil, &cfg.Provider)
	if err != nil {
		t.Fatalf("build video chain: %v", err)
	}

	modChecker := moderation.NewPermissiveChecker()
	quotaRepo := quota.NewMockRepository()
	quotaLimits := quota.Limits{TextDaily: 50, ImageDaily: 20}
	quotaSvc := quota.NewService(quotaRepo, quotaLimits, log)
	hashBank := hashtag.NewBank()
	jobQueue := queue.NewInProc(cfg.Queue.VideoMaxAttempts, log)

	genMod := generation.New(generation.Deps{
		DB:         nil,
		Config:     cfg,
		Logger:     log,
		TextChain:  textChain,
		ImageChain: imageChain,
		VideoChain: videoChain,
		Moderation: modChecker,
		Quota:      quotaSvc,
		Hashtag:    hashBank,
		Queue:      jobQueue,
		Store:      assetStore,
	})
	genMod.Handler.RegisterRoutes(v1, mw)

	ctx, cancel := context.WithCancel(context.Background())
	go jobQueue.Start(ctx, genMod.Service.ProcessVideoJob)

	quota.NewHandler(quotaSvc).RegisterRoutes(v1, mw)
	reminderMod := reminder.New(reminder.Deps{DB: nil, Config: cfg, Logger: log})
	reminderMod.Handler.RegisterRoutes(v1, mw)

	adminHandler := admin.NewHandler(admin.NewService(adminRepo, log))
	adminHandler.RegisterRoutes(v1, mw)

	ts := httptest.NewServer(engine)

	app := &testApp{
		server:    ts,
		client:    ts.Client(),
		jwtMgr:    jwtMgr,
		mailer:    recMailer,
		adminRepo: adminRepo,
		queue:     jobQueue,
		genMod:    genMod,
		cancelFn:  cancel,
	}

	t.Cleanup(func() {
		cancel()
		ts.Close()
		_ = os.RemoveAll("./storage")
	})

	return app
}

// e2eResponse wraps HTTP response metadata without leaking raw http.Response to satisfy bodyclose.
type e2eResponse struct {
	StatusCode int
	Header     http.Header
}

// Helpers for issuing HTTP requests to the live test server

func (a *testApp) postJSON(t *testing.T, path string, body any, bearer string) (e2eResponse, []byte) {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		if err := json.NewEncoder(&buf).Encode(body); err != nil {
			t.Fatalf("encode body: %v", err)
		}
	}
	req, err := http.NewRequest(http.MethodPost, a.server.URL+path, &buf)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	resp, err := a.client.Do(req)
	if err != nil {
		t.Fatalf("postJSON %s: %v", path, err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()
	var resBuf bytes.Buffer
	_, _ = resBuf.ReadFrom(resp.Body)
	return e2eResponse{StatusCode: resp.StatusCode, Header: resp.Header}, resBuf.Bytes()
}

func (a *testApp) get(t *testing.T, path string, bearer string) (e2eResponse, []byte) {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, a.server.URL+path, nil)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	resp, err := a.client.Do(req)
	if err != nil {
		t.Fatalf("get %s: %v", path, err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()
	var resBuf bytes.Buffer
	_, _ = resBuf.ReadFrom(resp.Body)
	return e2eResponse{StatusCode: resp.StatusCode, Header: resp.Header}, resBuf.Bytes()
}

func (a *testApp) putJSON(t *testing.T, path string, body any, bearer string) (e2eResponse, []byte) {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		if err := json.NewEncoder(&buf).Encode(body); err != nil {
			t.Fatalf("encode body: %v", err)
		}
	}
	req, err := http.NewRequest(http.MethodPut, a.server.URL+path, &buf)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	resp, err := a.client.Do(req)
	if err != nil {
		t.Fatalf("putJSON %s: %v", path, err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()
	var resBuf bytes.Buffer
	_, _ = resBuf.ReadFrom(resp.Body)
	return e2eResponse{StatusCode: resp.StatusCode, Header: resp.Header}, resBuf.Bytes()
}

func (a *testApp) deleteReq(t *testing.T, path string, bearer string) (e2eResponse, []byte) {
	t.Helper()
	req, err := http.NewRequest(http.MethodDelete, a.server.URL+path, nil)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	resp, err := a.client.Do(req)
	if err != nil {
		t.Fatalf("deleteReq %s: %v", path, err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()
	var resBuf bytes.Buffer
	_, _ = resBuf.ReadFrom(resp.Body)
	return e2eResponse{StatusCode: resp.StatusCode, Header: resp.Header}, resBuf.Bytes()
}

func (a *testApp) uploadFile(t *testing.T, path, field, filename string, content []byte, bearer string) (e2eResponse, []byte) {
	t.Helper()
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	fw, err := w.CreateFormFile(field, filename)
	if err != nil {
		t.Fatalf("create form file: %v", err)
	}
	if _, err := fw.Write(content); err != nil {
		t.Fatalf("write form file content: %v", err)
	}
	_ = w.Close()

	req, err := http.NewRequest(http.MethodPost, a.server.URL+path, &buf)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", w.FormDataContentType())
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	resp, err := a.client.Do(req)
	if err != nil {
		t.Fatalf("uploadFile %s: %v", path, err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()
	var resBuf bytes.Buffer
	_, _ = resBuf.ReadFrom(resp.Body)
	return e2eResponse{StatusCode: resp.StatusCode, Header: resp.Header}, resBuf.Bytes()
}

func extractTokenFromBody(t *testing.T, body string) string {
	t.Helper()
	idx := strings.Index(body, "token=")
	if idx == -1 {
		t.Fatalf("no token= found in email body:\n%s", body)
	}
	tokenPart := body[idx+len("token="):]
	end := strings.IndexAny(tokenPart, " \r\n\t\"'")
	if end != -1 {
		tokenPart = tokenPart[:end]
	}
	decoded, err := url.QueryUnescape(tokenPart)
	if err != nil {
		t.Fatalf("unescape token: %v", err)
	}
	return decoded
}

func makePNG(t *testing.T, w, h int) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatalf("encode png: %v", err)
	}
	return buf.Bytes()
}

// ── End-to-End Test Suite ───────────────────────────────────────────────────

func TestEndToEndBackendPipeline(t *testing.T) {
	app := setupE2EApp(t)

	// ── 1. Probe & OpenAPI Docs ──────────────────────────────────────────────
	t.Run("1_ProbesAndDocs", func(t *testing.T) {
		resp, body := app.get(t, "/healthz", "")
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("GET /healthz want 200, got %d (body=%s)", resp.StatusCode, string(body))
		}
		if !strings.Contains(string(body), `"status":"ok"`) {
			t.Fatalf("healthz body want status ok, got %s", string(body))
		}

		resp, body = app.get(t, "/openapi.yaml", "")
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("GET /openapi.yaml want 200, got %d", resp.StatusCode)
		}
		if !strings.Contains(string(body), "openapi:") {
			t.Fatalf("openapi.yaml missing openapi header")
		}

		resp, _ = app.get(t, "/docs", "")
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("GET /docs want 200, got %d", resp.StatusCode)
		}
	})

	// ── 2. Full Auth & Email Lifecycle ───────────────────────────────────────
	var (
		userEmail    = "shopkeeper@example.com"
		userPassword = "CorrectPassword123!"
		userID       string
		userToken    string
		refreshToken string
	)

	t.Run("2_AuthLifecycle", func(t *testing.T) {
		// 2.1 Short password rejected
		resp, _ := app.postJSON(t, "/v1/auth/register", gin.H{
			"email":    userEmail,
			"password": "123",
		}, "")
		if resp.StatusCode != http.StatusBadRequest {
			t.Fatalf("register short password: want 400, got %d", resp.StatusCode)
		}

		// 2.2 Valid registration
		resp, body := app.postJSON(t, "/v1/auth/register", gin.H{
			"email":    userEmail,
			"password": userPassword,
		}, "")
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("register want 201, got %d (body=%s)", resp.StatusCode, string(body))
		}

		var regResp struct {
			UserID           string `json:"user_id"`
			VerificationSent bool   `json:"verification_sent"`
		}
		if err := json.Unmarshal(body, &regResp); err != nil {
			t.Fatalf("unmarshal register response: %v", err)
		}
		if regResp.UserID == "" || !regResp.VerificationSent {
			t.Fatalf("invalid register response: %+v", regResp)
		}
		userID = regResp.UserID

		// Seed user into admin repository for admin-level lookups
		parsedUID, _ := uuid.Parse(userID)
		app.adminRepo.AddUser(&models.User{
			Base:  models.Base{ID: parsedUID},
			Email: userEmail,
			Role:  models.RoleUser,
		})

		// 2.3 Duplicate registration rejected with 409 Conflict
		resp, _ = app.postJSON(t, "/v1/auth/register", gin.H{
			"email":    userEmail,
			"password": userPassword,
		}, "")
		if resp.StatusCode != http.StatusConflict {
			t.Fatalf("duplicate register want 409, got %d", resp.StatusCode)
		}

		// 2.4 Verify email token captured from mailer
		msg, ok := app.mailer.LastMessage()
		if !ok || msg.To != userEmail {
			t.Fatalf("expected verification email sent to %s, got %+v", userEmail, msg)
		}
		verifyToken := extractTokenFromBody(t, msg.Body)

		// 2.5 Resend verification endpoint
		resp, _ = app.postJSON(t, "/v1/auth/verify-email/resend", gin.H{"email": userEmail}, "")
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("resend verification want 200, got %d", resp.StatusCode)
		}

		// 2.6 Log in before email verification -> succeeds, but token claims EmailVerified=false
		resp, body = app.postJSON(t, "/v1/auth/login", gin.H{
			"email":    userEmail,
			"password": userPassword,
		}, "")
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("login want 200, got %d (body=%s)", resp.StatusCode, string(body))
		}
		var tokens struct {
			AccessToken  string `json:"access_token"`
			RefreshToken string `json:"refresh_token"`
		}
		if err := json.Unmarshal(body, &tokens); err != nil {
			t.Fatalf("unmarshal tokens: %v", err)
		}

		// Confirm generation is blocked for unverified user
		resp, _ = app.postJSON(t, "/v1/generate/text", gin.H{
			"input_text": "Coffee beans on sale today!",
			"input_lang": "en",
			"platform":   "telegram",
		}, tokens.AccessToken)
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("unverified text generate want 403, got %d", resp.StatusCode)
		}

		// 2.7 Verify email using the token
		resp, _ = app.postJSON(t, "/v1/auth/verify-email", gin.H{"token": verifyToken}, "")
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("verify email want 200, got %d", resp.StatusCode)
		}

		// 2.8 Login now yields verified access token
		resp, body = app.postJSON(t, "/v1/auth/login", gin.H{
			"email":    userEmail,
			"password": userPassword,
		}, "")
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("login verified want 200, got %d", resp.StatusCode)
		}
		if err := json.Unmarshal(body, &tokens); err != nil {
			t.Fatalf("unmarshal tokens: %v", err)
		}
		userToken = tokens.AccessToken
		refreshToken = tokens.RefreshToken

		// 2.9 Refresh token rotation
		resp, body = app.postJSON(t, "/v1/auth/refresh", gin.H{"refresh_token": refreshToken}, "")
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("refresh token want 200, got %d (body=%s)", resp.StatusCode, string(body))
		}
		var newTokens struct {
			AccessToken  string `json:"access_token"`
			RefreshToken string `json:"refresh_token"`
		}
		if err := json.Unmarshal(body, &newTokens); err != nil {
			t.Fatalf("unmarshal rotated tokens: %v", err)
		}
		userToken = newTokens.AccessToken

		// 2.10 Replay attack / Reuse detection on old refresh token
		resp, _ = app.postJSON(t, "/v1/auth/refresh", gin.H{"refresh_token": refreshToken}, "")
		if resp.StatusCode != http.StatusUnauthorized {
			t.Fatalf("reused refresh token want 401, got %d", resp.StatusCode)
		}

		// 2.11 Password Reset Flow
		app.mailer.Clear()
		resp, _ = app.postJSON(t, "/v1/auth/password-reset/request", gin.H{"email": userEmail}, "")
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("password reset request want 200, got %d", resp.StatusCode)
		}
		resetMsg, ok := app.mailer.LastMessage()
		if !ok || resetMsg.To != userEmail {
			t.Fatalf("expected password reset email to %s", userEmail)
		}
		resetToken := extractTokenFromBody(t, resetMsg.Body)

		newPassword := "NewBrandSecret2026!"
		resp, _ = app.postJSON(t, "/v1/auth/password-reset/confirm", gin.H{
			"token":        resetToken,
			"new_password": newPassword,
		}, "")
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("password reset confirm want 200, got %d", resp.StatusCode)
		}

		// Old password fails, new password logs in
		resp, _ = app.postJSON(t, "/v1/auth/login", gin.H{"email": userEmail, "password": userPassword}, "")
		if resp.StatusCode != http.StatusUnauthorized {
			t.Fatalf("old password login want 401, got %d", resp.StatusCode)
		}

		resp, body = app.postJSON(t, "/v1/auth/login", gin.H{"email": userEmail, "password": newPassword}, "")
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("new password login want 200, got %d", resp.StatusCode)
		}
		_ = json.Unmarshal(body, &tokens)
		userToken = tokens.AccessToken
	})

	// ── 3. Quota Management ──────────────────────────────────────────────────
	t.Run("3_QuotaInspection", func(t *testing.T) {
		resp, body := app.get(t, "/v1/quota/me", userToken)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("GET /v1/quota/me want 200, got %d (body=%s)", resp.StatusCode, string(body))
		}

		var q quota.UsageResponse
		if err := json.Unmarshal(body, &q); err != nil {
			t.Fatalf("unmarshal quota response: %v", err)
		}
		if q.TextCap != 50 || q.ImageCap != 20 {
			t.Fatalf("unexpected quota limits: %+v", q)
		}
	})

	// ── 4. Brand Kit CRUD & Tenant Isolation ─────────────────────────────────
	t.Run("4_BrandKitAndTenantIsolation", func(t *testing.T) {
		// 4.1 Update Brand Kit for User A
		brandKitPayload := gin.H{
			"brand_name":          "Tomoca Coffee",
			"tagline":             "Finest Ethiopian Roast",
			"primary_color_hex":   "#4A2C11",
			"secondary_color_hex": "#D4AF37",
			"tone_of_voice":       "Warm and Traditional",
			"contact_info":        "+251911000000",
		}
		resp, body := app.putJSON(t, "/v1/brand-kits/"+userID, brandKitPayload, userToken)
		if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
			t.Fatalf("PUT /brand-kits/:id want 200/201, got %d (body=%s)", resp.StatusCode, string(body))
		}

		// 4.2 Fetch back and assert persistence
		resp, body = app.get(t, "/v1/brand-kits/"+userID, userToken)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("GET /brand-kits/:id want 200, got %d (body=%s)", resp.StatusCode, string(body))
		}
		if !strings.Contains(string(body), "Tomoca Coffee") || !strings.Contains(string(body), "#4A2C11") {
			t.Fatalf("brand kit response missing expected fields: %s", string(body))
		}

		// 4.3 Tenant Isolation: Register User B and verify they cannot read or write User A's kit
		app.postJSON(t, "/v1/auth/register", gin.H{
			"email":    "attacker@example.com",
			"password": "AttackerPassword123!",
		}, "")
		resp, body = app.postJSON(t, "/v1/auth/login", gin.H{
			"email":    "attacker@example.com",
			"password": "AttackerPassword123!",
		}, "")
		var attackerTokens struct {
			AccessToken string `json:"access_token"`
		}
		_ = json.Unmarshal(body, &attackerTokens)

		// User B reading User A's kit must be 404 (not found / isolated)
		resp, _ = app.get(t, "/v1/brand-kits/"+userID, attackerTokens.AccessToken)
		if resp.StatusCode != http.StatusNotFound {
			t.Fatalf("cross-tenant GET brand kit want 404, got %d", resp.StatusCode)
		}

		// User B updating User A's kit must also be 404
		resp, _ = app.putJSON(t, "/v1/brand-kits/"+userID, brandKitPayload, attackerTokens.AccessToken)
		if resp.StatusCode != http.StatusNotFound {
			t.Fatalf("cross-tenant PUT brand kit want 404, got %d", resp.StatusCode)
		}
	})

	// ── 5. Asset Upload & Hardening ──────────────────────────────────────────
	t.Run("5_AssetUpload", func(t *testing.T) {
		// 5.1 Unauthenticated upload rejected
		resp, _ := app.uploadFile(t, "/v1/assets", "file", "logo.png", makePNG(t, 256, 256), "")
		if resp.StatusCode != http.StatusUnauthorized {
			t.Fatalf("unauthenticated asset upload want 401, got %d", resp.StatusCode)
		}

		// 5.2 Invalid file type rejected
		resp, _ = app.uploadFile(t, "/v1/assets", "file", "script.sh", []byte("#!/bin/sh\necho hack"), userToken)
		if resp.StatusCode != http.StatusBadRequest {
			t.Fatalf("non-image asset upload want 400, got %d", resp.StatusCode)
		}

		// 5.3 Valid PNG image uploaded successfully
		pngBytes := makePNG(t, 512, 512)
		resp, body := app.uploadFile(t, "/v1/assets", "file", "logo.png", pngBytes, userToken)
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("valid asset upload want 201, got %d (body=%s)", resp.StatusCode, string(body))
		}

		var assetResp struct {
			ID       string `json:"id"`
			Width    int    `json:"width"`
			Height   int    `json:"height"`
			MimeType string `json:"mime_type"`
		}
		if err := json.Unmarshal(body, &assetResp); err != nil {
			t.Fatalf("unmarshal asset response: %v", err)
		}
		if assetResp.ID == "" || assetResp.Width != 512 || assetResp.Height != 512 || assetResp.MimeType != "image/png" {
			t.Fatalf("invalid asset response payload: %+v", assetResp)
		}
	})

	// ── 6. AI Content Generation (Text, Image, Video) ────────────────────────
	t.Run("6_GenerationPipeline", func(t *testing.T) {
		// 6.1 Generate Text Caption
		parsedBrandUUID, _ := uuid.Parse(userID)
		textReq := gin.H{
			"input_text":   "Special holiday discount on dark roast beans",
			"input_lang":   "en",
			"platform":     "telegram",
			"brand_kit_id": parsedBrandUUID,
		}
		resp, body := app.postJSON(t, "/v1/generate/text", textReq, userToken)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("POST /v1/generate/text want 200, got %d (body=%s)", resp.StatusCode, string(body))
		}

		var textResp struct {
			CaptionEN    string   `json:"caption_en"`
			CaptionAM    string   `json:"caption_am"`
			Hashtags     []string `json:"hashtags"`
			Hook         string   `json:"hook"`
			CallToAction string   `json:"call_to_action"`
		}
		if err := json.Unmarshal(body, &textResp); err != nil {
			t.Fatalf("unmarshal text response: %v", err)
		}
		if len(textResp.Hashtags) == 0 || textResp.CaptionEN == "" {
			t.Fatalf("invalid text generation response: %+v", textResp)
		}

		// 6.2 Quota used count incremented
		resp, body = app.get(t, "/v1/quota/me", userToken)
		var q quota.UsageResponse
		_ = json.Unmarshal(body, &q)
		if q.TextUsed < 1 {
			t.Fatalf("expected TextUsed >= 1, got %d", q.TextUsed)
		}

		// 6.3 Image Generation: Invalid aspect ratio rejected
		resp, _ = app.postJSON(t, "/v1/generate/image", gin.H{
			"caption_en":   "A cup of steaming coffee on a wooden table",
			"aspect_ratio": "16:9", // invalid per contract
		}, userToken)
		if resp.StatusCode != http.StatusBadRequest {
			t.Fatalf("invalid aspect_ratio want 400, got %d", resp.StatusCode)
		}

		// 6.4 Image Generation: Valid 1:1 ratio
		resp, body = app.postJSON(t, "/v1/generate/image", gin.H{
			"caption_en":   "A cup of steaming coffee on a wooden table",
			"aspect_ratio": "1:1",
		}, userToken)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("POST /v1/generate/image want 200, got %d (body=%s)", resp.StatusCode, string(body))
		}
		var imgResp struct {
			AssetID  string `json:"asset_id"`
			ImageURL string `json:"image_url"`
			Width    int    `json:"width"`
			Height   int    `json:"height"`
		}
		if err := json.Unmarshal(body, &imgResp); err != nil {
			t.Fatalf("unmarshal image response: %v", err)
		}
		if imgResp.AssetID == "" || imgResp.ImageURL == "" {
			t.Fatalf("invalid image response: %+v", imgResp)
		}

		// 6.5 Async Video Generation Flow
		resp, body = app.postJSON(t, "/v1/generate/video", gin.H{
			"storyboard_text":  "Coffee beans roasted and brewed into espresso",
			"duration_seconds": 15,
		}, userToken)
		if resp.StatusCode != http.StatusAccepted {
			t.Fatalf("POST /v1/generate/video want 202, got %d (body=%s)", resp.StatusCode, string(body))
		}

		var jobResp struct {
			ID     string `json:"id"`
			Status string `json:"status"`
		}
		if err := json.Unmarshal(body, &jobResp); err != nil {
			t.Fatalf("unmarshal job response: %v", err)
		}
		if jobResp.ID == "" {
			t.Fatalf("expected job id, got empty")
		}

		// Poll GET /v1/jobs/:id until completed
		var finalStatus string
		for i := 0; i < 100; i++ {
			time.Sleep(50 * time.Millisecond)
			resp, body = app.get(t, "/v1/jobs/"+jobResp.ID, userToken)
			if resp.StatusCode == http.StatusOK {
				var curJob struct {
					Status string `json:"status"`
				}
				_ = json.Unmarshal(body, &curJob)
				finalStatus = curJob.Status
				if curJob.Status == string(models.JobDone) {
					break
				}
			}
		}
		if finalStatus != string(models.JobDone) {
			t.Fatalf("async video job did not reach 'done' status, got %q", finalStatus)
		}
	})

	// ── 7. Reminders ─────────────────────────────────────────────────────────
	t.Run("7_Reminders", func(t *testing.T) {
		// Invalid timestamp rejected
		resp, _ := app.postJSON(t, "/v1/reminders", gin.H{
			"draft_local_id":   "draft-123",
			"scheduled_at_utc": "not-a-timestamp",
		}, userToken)
		if resp.StatusCode != http.StatusBadRequest {
			t.Fatalf("invalid reminder timestamp want 400, got %d", resp.StatusCode)
		}

		// Valid reminder scheduled
		scheduled := time.Now().UTC().Add(24 * time.Hour).Format(time.RFC3339)
		resp, body := app.postJSON(t, "/v1/reminders", gin.H{
			"draft_local_id":   "draft-123",
			"scheduled_at_utc": scheduled,
		}, userToken)
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("POST /v1/reminders want 201, got %d (body=%s)", resp.StatusCode, string(body))
		}
		var remResp struct {
			ID string `json:"id"`
		}
		if err := json.Unmarshal(body, &remResp); err != nil || remResp.ID == "" {
			t.Fatalf("invalid reminder response: %s", string(body))
		}
	})

	// ── 8. Admin Moderation, Usage Metrics & Limit Overrides ──────────────────
	t.Run("8_AdminOperations", func(t *testing.T) {
		// 8.1 Non-admin user rejected from admin endpoints
		resp, _ := app.get(t, "/v1/admin/usage", userToken)
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("non-admin GET /admin/usage want 403, got %d", resp.StatusCode)
		}

		// 8.2 Admin user minted
		adminID := uuid.New()
		adminToken, err := app.jwtMgr.GenerateAccess(adminID.String(), platformauth.RoleAdmin, true)
		if err != nil {
			t.Fatalf("generate admin token: %v", err)
		}

		// 8.3 Admin access usage metrics
		resp, body := app.get(t, "/v1/admin/usage", adminToken)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("admin GET /admin/usage want 200, got %d (body=%s)", resp.StatusCode, string(body))
		}
		var usageResp admin.UsageSummary
		if err := json.Unmarshal(body, &usageResp); err != nil {
			t.Fatalf("unmarshal usage metrics: %v", err)
		}

		// 8.4 Seed a moderation flag and verify admin review
		flagID := uuid.New()
		targetUserUUID, _ := uuid.Parse(userID)
		app.adminRepo.AddFlag(&models.ModerationFlag{
			Base:          models.Base{ID: flagID},
			UserID:        targetUserUUID,
			InputSnapshot: "Potentially flagged text",
			Reason:        "keyword trigger",
			CreatedAt:     time.Now().UTC(),
		})

		// 8.5 Admin inspect moderation flags
		resp, body = app.get(t, "/v1/admin/flags?status=pending", adminToken)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("admin GET /admin/flags want 200, got %d (body=%s)", resp.StatusCode, string(body))
		}
		var flagsResp struct {
			Flags []models.ModerationFlag `json:"flags"`
		}
		if err := json.Unmarshal(body, &flagsResp); err != nil {
			t.Fatalf("unmarshal flags response: %v", err)
		}
		if len(flagsResp.Flags) == 0 {
			t.Fatalf("expected at least 1 pending moderation flag")
		}

		// 8.6 Admin reviews the flag
		resp, _ = app.postJSON(t, "/v1/admin/flags/"+flagID.String()+"/review", nil, adminToken)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("review flag want 200, got %d", resp.StatusCode)
		}

		// Duplicate review on already-reviewed flag returns 409 Conflict
		resp, _ = app.postJSON(t, "/v1/admin/flags/"+flagID.String()+"/review", nil, adminToken)
		if resp.StatusCode != http.StatusConflict {
			t.Fatalf("duplicate review flag want 409, got %d", resp.StatusCode)
		}

		// 8.7 Admin override user daily quota limits
		limitReq := gin.H{
			"daily_text_quota":  100,
			"daily_image_quota": 40,
		}
		resp, body = app.putJSON(t, "/v1/admin/users/"+targetUserUUID.String()+"/limits", limitReq, adminToken)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("PUT /admin/users/:id/limits want 200, got %d (body=%s)", resp.StatusCode, string(body))
		}

		// Negative limits rejected with 400
		badLimitReq := gin.H{"daily_text_quota": -5}
		resp, _ = app.putJSON(t, "/v1/admin/users/"+targetUserUUID.String()+"/limits", badLimitReq, adminToken)
		if resp.StatusCode != http.StatusBadRequest {
			t.Fatalf("negative limit override want 400, got %d", resp.StatusCode)
		}
	})

	// ── 9. Account Deletion & Teardown ───────────────────────────────────────
	t.Run("9_AccountDeletion", func(t *testing.T) {
		// 9.1 Delete account
		resp, _ := app.deleteReq(t, "/v1/auth/account", userToken)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("DELETE /v1/auth/account want 200, got %d", resp.StatusCode)
		}

		// 9.2 Subsequent login is rejected
		resp, _ = app.postJSON(t, "/v1/auth/login", gin.H{
			"email":    userEmail,
			"password": "NewBrandSecret2026!",
		}, "")
		if resp.StatusCode != http.StatusUnauthorized {
			t.Fatalf("login deleted user want 401, got %d", resp.StatusCode)
		}
	})
}
