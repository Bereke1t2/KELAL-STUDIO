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
	platformauth "github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/database"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/email"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx/middleware"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/logger"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider/factory"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/queue"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/storage"
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

	// Database: skipped entirely in mock mode.
	var db *gorm.DB
	if !cfg.UseMockData {
		db, err = database.Connect(cfg.DB)
		if err != nil {
			return err
		}
		if migrateOnly || !cfg.IsProduction() {
			if err := database.AutoMigrate(db); err != nil {
				return err
			}
			log.Info("database migrated")
		}
	} else if migrateOnly {
		return fmt.Errorf("cannot run -migrate-only with USE_MOCK_DATA=true")
	}

	if migrateOnly {
		return nil
	}

	// Shared singletons.
	jwtMgr := platformauth.NewManager(
		cfg.JWT.AccessSecret, cfg.JWT.RefreshSecret, cfg.JWT.AccessTTL, cfg.JWT.RefreshTTL,
	)

	// Blob store for uploaded assets.
	var assetStore storage.Store
	if cfg.UseMockData {
		assetStore = storage.NewMemory()
	} else {
		assetStore, err = storage.NewFS(cfg.Asset.StorageDir)
		if err != nil {
			return err
		}
	}

	// Outbound email.
	// Outbound email: a real SMTP sender in production, the dev LogSender by
	// default. New fails fast on a misconfigured provider (config.validate has
	// already refused the log sender under APP_ENV=production).
	mailer, err := email.New(email.Options{
		Provider:     cfg.Email.Provider,
		From:         cfg.Email.From,
		SMTPHost:     cfg.Email.SMTPHost,
		SMTPPort:     cfg.Email.SMTPPort,
		SMTPUsername: cfg.Email.SMTPUsername,
		SMTPPassword: cfg.Email.SMTPPassword,
	}, log)
	if err != nil {
		return err
	}

	// Global middleware.
	engine, v1 := httpx.NewRouter(
		cfg.IsProduction(),
		middleware.RequestID(),
		middleware.Logger(log),
		middleware.Recover(log),
		middleware.CORS(),
		middleware.IPRateLimit(cfg.RateLim.PerIPPerMinute),
	)

	if !cfg.IsProduction() {
		apidocs.Mount(engine, api.Spec)
	}

	mw := middleware.Set{
		AuthRequired:  middleware.Auth(jwtMgr),
		AdminOnly:     middleware.AdminOnly(),
		UserRateLimit: middleware.UserRateLimit(cfg.RateLim.PerUserPerMinute),
		EmailVerified: middleware.EmailVerifiedRequired(),
	}

	// ── Feature composition ───────────────────────────────────────────────

	// Auth, brandkit, asset — simple features.
	// ── Feature composition — the one place features are wired ──────────────
	// Every feature is implemented: auth, brandkit, asset, generation, quota,
	// reminder, and admin all register routes below. moderation and hashtag are
	// internal (no routes) — they are dependencies of generation, not mounted
	// here.
	auth.New(auth.Deps{DB: db, JWT: jwtMgr, Config: cfg, Logger: log, Mailer: mailer}).RegisterRoutes(v1, mw)
	brandkit.New(brandkit.Deps{DB: db, Config: cfg, Logger: log}).RegisterRoutes(v1, mw)
	asset.New(asset.Deps{DB: db, Config: cfg, Logger: log, Store: assetStore}).RegisterRoutes(v1, mw)

	// Build provider chains from config.
	textChain, err := factory.BuildTextChain(
		cfg.Provider.TextOrder,
		cfg.Provider.Timeout,
		nil,
		&cfg.Provider,
	)
	if err != nil {
		return fmt.Errorf("building text provider chain: %w", err)
	}
	imageChain, err := factory.BuildImageChain(
		cfg.Provider.ImageOrder,
		cfg.Provider.Timeout,
		nil,
		&cfg.Provider,
	)
	if err != nil {
		return fmt.Errorf("building image provider chain: %w", err)
	}
	videoChain, err := factory.BuildVideoChain(
		cfg.Provider.VideoOrder,
		cfg.Provider.Timeout,
		nil,
		&cfg.Provider,
	)
	if err != nil {
		return fmt.Errorf("building video provider chain: %w", err)
	}

	// Moderation.
	var modChecker moderation.Checker
	switch {
	case cfg.UseMockData:
		modChecker = moderation.NewPermissiveChecker()
		log.Info("moderation: permissive (mock mode)")
	case cfg.Moderation.Provider == "openai":
		if cfg.Moderation.APIKey == "" {
			return fmt.Errorf("MODERATION_PROVIDER=openai requires OPENAI_API_KEY")
		}
		modChecker = moderation.NewOpenAIChecker(cfg.Moderation.APIKey)
		log.Info("moderation: OpenAI Moderation API")
	case cfg.Moderation.Provider == "stub":
		modChecker = moderation.NewStubChecker()
		log.Info("moderation: stub (all content refused)")
	default:
		modChecker = moderation.NewPermissiveChecker()
		log.Info("moderation: permissive (no provider configured)")
	}

	// Quota.
	var quotaRepo quota.Repository
	if cfg.UseMockData || db == nil {
		quotaRepo = quota.NewMockRepository()
	} else {
		quotaRepo = quota.NewGormRepository(db)
	}
	quotaLimits := quota.Limits{
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

	// Hashtag bank.
	hashBank := hashtag.NewBank()

	// Queue for async video generation.
	jobQueue := queue.NewInProc(cfg.Queue.VideoMaxAttempts, log)

	// Generation feature.
	genMod := generation.New(generation.Deps{
		DB:         db,
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

	// Start in-process queue consumer for video jobs.
	go func() {
		ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
		defer stop()
		jobQueue.Start(ctx, genMod.Service.ProcessVideoJob)
	}()

	// Quota endpoint.
	quota.NewHandler(quotaSvc).RegisterRoutes(v1, mw)

	// Reminder feature.
	reminderMod := reminder.New(reminder.Deps{DB: db, Config: cfg, Logger: log})
	reminderMod.Handler.RegisterRoutes(v1, mw)

	// Background scheduler for due reminders (every 60 seconds).
	go func() {
		ticker := time.NewTicker(60 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			reminderMod.Service.FireDueReminders(context.Background())
		}
	}()

	// Admin feature.
	admin.New(admin.Deps{DB: db, Config: cfg, Logger: log}).RegisterRoutes(v1, mw)

	// HTTP server.
	srv := &http.Server{
		Addr:              ":" + cfg.HTTPPort,
		Handler:           engine,
		ReadHeaderTimeout: 10 * time.Second,
	}

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
