package auth

import (
	"log/slog"

	"gorm.io/gorm"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/email"
)

// Deps are everything the auth feature needs from the composition root
// (cmd/api). Passing them in — rather than reaching for globals — is what lets
// tests construct the feature with a mock repo and fake clock-free manager.
type Deps struct {
	DB     *gorm.DB // may be nil when Config.UseMockData is true
	JWT    *auth.Manager
	Config *config.Config
	Logger *slog.Logger
	Mailer email.Sender // optional; a dev LogSender is used when nil
}

// New wires the feature and returns its Handler. It selects the in-memory or
// Postgres adapter from configuration — the backend analogue of the mobile
// app's per-feature @module gated on Env.useMockApi. This is THE function every
// other feature's module.New copies.
func New(d Deps) *Handler {
	var repo Repository
	if d.Config.UseMockData || d.DB == nil {
		repo = NewMockRepository()
	} else {
		repo = NewGormRepository(d.DB)
	}
	// Fall back to the dev LogSender when the root didn't wire a mailer (e.g.
	// handler tests). New(log) with no provider never errors.
	mailer := d.Mailer
	if mailer == nil {
		mailer, _ = email.New(email.Options{Provider: email.ProviderLog}, d.Logger)
	}
	svc := NewService(repo, d.JWT, d.Logger, mailer, ServiceConfig{
		PublicBaseURL:          d.Config.PublicBaseURL,
		VerificationTTL:        d.Config.Auth.EmailVerificationTTL,
		PasswordResetTTL:       d.Config.Auth.PasswordResetTTL,
		LoginMaxFailedAttempts: d.Config.Auth.LoginMaxFailedAttempts,
		LoginLockoutDuration:   d.Config.Auth.LoginLockoutDuration,
	})
	return NewHandler(svc)
}
