// Package admin — see domain.go for the package overview. This file is the wiring
// seam.
package admin

import (
	"log/slog"

	"gorm.io/gorm"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
)

// Deps are everything the admin feature needs from the composition root
// (cmd/api). Passing them in — rather than reaching for globals — is what lets
// tests construct the feature with a mock repo. Auth and the admin-role gate are
// applied by the shared middleware.Set at route registration, so no JWT manager
// is needed here.
type Deps struct {
	DB     *gorm.DB // may be nil when Config.UseMockData is true
	Config *config.Config
	Logger *slog.Logger
}

// New wires the feature and returns its Handler. It selects the in-memory or
// Postgres adapter from configuration — exactly like brandkit.New / auth.New.
func New(d Deps) *Handler {
	var repo Repository
	if d.Config.UseMockData || d.DB == nil {
		repo = NewMockRepository()
	} else {
		repo = NewGormRepository(d.DB)
	}
	return NewHandler(NewService(repo, d.Logger))
}
