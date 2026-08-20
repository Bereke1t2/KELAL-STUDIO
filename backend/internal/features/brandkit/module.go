// Package brandkit — see domain.go for the package overview. This file is the
// wiring seam.
package brandkit

import (
	"log/slog"

	"gorm.io/gorm"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
)

// Deps are everything the brand-kit feature needs from the composition root
// (cmd/api). Passing them in — rather than reaching for globals — is what lets
// tests construct the feature with a mock repo. Auth is enforced by the shared
// middleware.Set at route registration, so no JWT manager is needed here.
type Deps struct {
	DB     *gorm.DB // may be nil when Config.UseMockData is true
	Config *config.Config
	Logger *slog.Logger
}

// New wires the feature and returns its Handler. It selects the in-memory or
// Postgres adapter from configuration — the backend analogue of the mobile
// app's per-feature @module gated on Env.useMockApi, exactly like auth.New.
func New(d Deps) *Handler {
	var repo Repository
	if d.Config.UseMockData || d.DB == nil {
		repo = NewMockRepository()
	} else {
		repo = NewGormRepository(d.DB)
	}
	return NewHandler(NewService(repo, d.Logger))
}
