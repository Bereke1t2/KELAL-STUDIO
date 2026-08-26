// Package asset — see domain.go for the package overview. This file is the
// wiring seam.
package asset

import (
	"log/slog"

	"gorm.io/gorm"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/storage"
)

// Deps are everything the asset feature needs from the composition root
// (cmd/api). The blob Store is injected rather than built here so cmd/api owns
// the single filesystem root and tests can supply an in-memory store — the same
// dependency-injection seam the auth feature uses for its mailer. Auth and
// per-user rate limiting are enforced by the shared middleware.Set at route
// registration, so no JWT manager is needed here.
type Deps struct {
	DB     *gorm.DB // may be nil when Config.UseMockData is true
	Config *config.Config
	Logger *slog.Logger
	Store  storage.Store
}

// New wires the feature and returns its Handler. It selects the in-memory or
// Postgres ROW adapter from configuration (the blob Store is chosen by cmd/api),
// exactly like brandkit.New — the backend analogue of the mobile app's per-feature
// module gated on Env.useMockApi.
func New(d Deps) *Handler {
	var repo Repository
	if d.Config.UseMockData || d.DB == nil {
		repo = NewMockRepository()
	} else {
		repo = NewGormRepository(d.DB)
	}
	return NewHandler(NewService(repo, d.Store, d.Config.Asset, d.Logger))
}
