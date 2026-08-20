package auth

import (
	"log/slog"

	"gorm.io/gorm"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
)

// Deps are everything the auth feature needs from the composition root
// (cmd/api). Passing them in — rather than reaching for globals — is what lets
// tests construct the feature with a mock repo and fake clock-free manager.
type Deps struct {
	DB     *gorm.DB // may be nil when Config.UseMockData is true
	JWT    *auth.Manager
	Config *config.Config
	Logger *slog.Logger
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
	svc := NewService(repo, d.JWT, d.Logger, !d.Config.IsProduction())
	return NewHandler(svc)
}
