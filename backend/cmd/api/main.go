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

	// Blob store for uploaded assets. In mock mode it lives in memory (like the
	// in-memory repos); otherwise it's a filesystem store rooted OUTSIDE any web
	// root (config.validate enforces an absolute path in production).
	var assetStore storage.Store
	if cfg.UseMockData {
		assetStore = storage.NewMemory()
	} else {
		assetStore, err = storage.NewFS(cfg.Asset.StorageDir)
		if err != nil {
			return err
		}
	}

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
		EmailVerified: middleware.EmailVerifiedRequired(),
	}

	// ── Feature composition — the one place features are wired ──────────────
	// Auth is fully implemented; the rest are stubs returning not_implemented
	// (see internal/features/*). Each takes the same (v1, mw) so wiring is
	// uniform. moderation and hashtag are internal (no routes) — they'll be
	// dependencies of generation, not mounted here.
	auth.New(auth.Deps{DB: db, JWT: jwtMgr, Config: cfg, Logger: log, Mailer: mailer}).RegisterRoutes(v1, mw)
	brandkit.New(brandkit.Deps{DB: db, Config: cfg, Logger: log}).RegisterRoutes(v1, mw)
	asset.New(asset.Deps{DB: db, Config: cfg, Logger: log, Store: assetStore}).RegisterRoutes(v1, mw)
	generation.New().RegisterRoutes(v1, mw)
	quota.New().RegisterRoutes(v1, mw)
	reminder.New().RegisterRoutes(v1, mw)
	admin.New().RegisterRoutes(v1, mw)

	// TODO(generation/video): build the provider chains (factory.BuildTextChain
	// / BuildImageChain from cfg.Provider) and the queue here, then pass them
	// into generation.New once that feature consumes them.

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
