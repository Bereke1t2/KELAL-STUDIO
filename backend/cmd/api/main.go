// Command api is the Kelal Studio backend HTTP server. It is the composition
// root: the ONLY place that reads config, dials the database, constructs the
// shared singletons, and wires every feature onto the /v1 router. Adding a
// feature is one line in run().
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"gorm.io/gorm"

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
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apidocs"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider/factory"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/queue"
	platformauth "github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/database"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/logger"
)

func main() {
	migrateOnly := flag.Bool("migrate-only", false, "run database migrations (AutoMigrate) and exit")
	flag.Parse()

	if err := run(*migrateOnly); err != nil {
		fmt.Fprintln(os.Stderr, "fatal:", err)
		os.Exit(1)
	}
}

func run(migrateOnly bool) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	log := logger.New(cfg.LogLevel)

	// Database: skipped entirely in mock mode (the analogue of the mobile app
	// running on its fake data layer). db stays nil and every feature module
	// falls back to its in-memory repository.
	var db *gorm.DB
	if !cfg.UseMockData {
		db, err = database.Connect(cfg.DB)
		if err != nil {
			return err
		}
		// AutoMigrate is the dev/V1 schema source (see database/migrate.go). In
		// production the versioned migrations/ are applied out-of-band, so we
		// only auto-migrate outside production or when explicitly asked.
		if migrateOnly || !cfg.IsProduction() {
			if err := database.AutoMigrate(db); err != nil {
				return err
			}
			log.Info("database migrated")
		}
	} else if migrateOnly {
		return fmt.Errorf("cannot run -migrate-only with USE_MOCK_DATA=true (there is no database)")
	}

	if migrateOnly {
		return nil
	}

	// Shared singletons.
	jwtMgr := platformauth.NewManager(
		cfg.JWT.AccessSecret, cfg.JWT.RefreshSecret, cfg.JWT.AccessTTL, cfg.JWT.RefreshTTL,
	)

	// Global middleware (applied once, in order) + the per-route middleware set
	// features apply selectively.
	engine, v1 := httpx.NewRouter(
		cfg.IsProduction(),
		middleware.RequestID(),
		middleware.Logger(log),
		middleware.Recover(log),
		middleware.CORS(),
		middleware.IPRateLimit(cfg.RateLim.PerIPPerMinute),
	)

	// API docs: the raw contract + an interactive Swagger UI, mounted on the
	// engine root (like /healthz) — non-production only, since they document the
	// surface rather than being part of it (see internal/platform/apidocs).
	if !cfg.IsProduction() {
		apidocs.Mount(engine, api.Spec)
	}

	mw := middleware.Set{
		AuthRequired:  middleware.Auth(jwtMgr),
		AdminOnly:     middleware.AdminOnly(),
		UserRateLimit: middleware.UserRateLimit(cfg.RateLim.PerUserPerMinute),
	}

	// ── Feature composition — the one place features are wired ──────────────
	// Auth is fully implemented; the rest are stubs returning not_implemented
	// (see internal/features/*). Each takes the same (v1, mw) so wiring is
	// uniform. moderation and hashtag are internal (no routes) — they'll be
	// dependencies of generation, not mounted here.
	auth.New(auth.Deps{DB: db, JWT: jwtMgr, Config: cfg, Logger: log}).RegisterRoutes(v1, mw)
	brandkit.New(brandkit.Deps{DB: db, Config: cfg, Logger: log}).RegisterRoutes(v1, mw)
	asset.New().RegisterRoutes(v1, mw)
	// Build the provider chains from config.
	textChain, err := factory.BuildTextChain(
		cfg.Provider.TextOrder,
		cfg.Provider.Timeout,
		nil, // telemetry func — wire to persistence when GenerationRecord write is built
	)
	if err != nil {
		return fmt.Errorf("building text provider chain: %w", err)
	}
	imageChain, err := factory.BuildImageChain(
		cfg.Provider.ImageOrder,
		cfg.Provider.Timeout,
		nil,
	)
	if err != nil {
		return fmt.Errorf("building image provider chain: %w", err)
	}
	// Moderation: internal service, no HTTP routes.
	// - USE_MOCK_DATA=true  → permissive (all content allowed, for testing)
	// - MODERATION_PROVIDER=openai → real OpenAI Moderation API
	// - MODERATION_PROVIDER=stub   → fail-closed (refuses everything)
	// - unset/empty            → permissive (safe default for dev)
	var modChecker moderation.Checker
	switch {
	case cfg.UseMockData:
		modChecker = moderation.NewPermissiveChecker()
		log.Info("moderation: permissive (mock mode — all content allowed)")
	case cfg.Moderation.Provider == "openai":
		if cfg.Moderation.APIKey == "" {
			return fmt.Errorf("MODERATION_PROVIDER=openai requires OPENAI_API_KEY to be set")
		}
		modChecker = moderation.NewOpenAIChecker(cfg.Moderation.APIKey)
		log.Info("moderation: OpenAI Moderation API")
	case cfg.Moderation.Provider == "stub":
		modChecker = moderation.NewStubChecker()
		log.Info("moderation: stub (all content refused)")
	default:
		modChecker = moderation.NewPermissiveChecker()
		log.Info("moderation: permissive (no provider configured — all content allowed)")
	}

	// Quota: build the shared service used by both the quota endpoint and
	// the generation feature's pre-call enforcement.
	var quotaRepo quota.Repository
	if cfg.UseMockData || db == nil {
		quotaRepo = quota.NewMockRepository()
	} else {
		quotaRepo = quota.NewGormRepository(db)
	}
	quotaLimits := quota.QuotaLimits{
		TextDaily:  cfg.Quota.TextDaily,
		ImageDaily: cfg.Quota.ImageDaily,
	}
	if quotaLimits.TextDaily <= 0 {
		quotaLimits.TextDaily = 50
	}
	if quotaLimits.ImageDaily <= 0 {
		quotaLimits.ImageDaily = 20
	}
	quotaSvc := quota.NewService(quotaRepo, quotaLimits, log)

	// Hashtag bank: curated, platform-aware hashtag source (PRD §6.3).
	// Internal service — no HTTP routes; generation merges its output
	// with provider-generated hashtags.
	hashBank := hashtag.NewBank()

	// Queue: in-process job queue for async video generation (PRD §10.3).
	// With the in-process driver, the API process itself consumes jobs —
	// the separate cmd/worker binary is the shape for a real broker.
	jobQueue := queue.NewInProc(cfg.Queue.VideoMaxAttempts, log)

	genMod := generation.New(generation.Deps{
		DB:         db,
		Config:     cfg,
		Logger:     log,
		TextChain:  textChain,
		ImageChain: imageChain,
		Moderation: modChecker,
		Quota:      quotaSvc,
		Hashtag:    hashBank,
		Queue:      jobQueue,
	})
	genMod.Handler.RegisterRoutes(v1, mw)

	// Start the in-process queue consumer for video jobs. This runs in a
	// goroutine and processes jobs as they are enqueued by the API.
	go func() {
		ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
		defer stop()
		jobQueue.Start(ctx, genMod.Service.ProcessVideoJob)
	}()
	quota.NewHandler(quotaSvc).RegisterRoutes(v1, mw)
	reminderMod := reminder.New(reminder.Deps{DB: db, Config: cfg, Logger: log})
	reminderMod.Handler.RegisterRoutes(v1, mw)

	// Background scheduler: checks for due reminders every 60 seconds and
	// fires them (PRD §6.12). In V1 this logs the notification; a real
	// implementation would dispatch push notifications via FCM/SNS.
	go func() {
		ticker := time.NewTicker(60 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			reminderMod.Service.FireDueReminders(context.Background())
		}
	}()
	admin.New().RegisterRoutes(v1, mw)

	srv := &http.Server{
		Addr:              ":" + cfg.HTTPPort,
		Handler:           engine,
		ReadHeaderTimeout: 10 * time.Second,
	}

	// Run the server and shut it down gracefully on SIGINT/SIGTERM.
	serverErr := make(chan error, 1)
	go func() {
		log.Info("api listening", "port", cfg.HTTPPort, "env", cfg.Env, "mock_data", cfg.UseMockData)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErr <- err
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

	select {
	case err := <-serverErr:
		return err
	case sig := <-stop:
		log.Info("shutting down", "signal", sig.String())
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		return srv.Shutdown(ctx)
	}
}
