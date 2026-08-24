package quota

import (
	"log/slog"

	"gorm.io/gorm"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
)

// Deps are everything the quota feature needs from the composition root.
type Deps struct {
	DB     *gorm.DB // may be nil when Config.UseMockData is true
	Config *config.Config
	Logger *slog.Logger
}

// New wires the feature and returns its Handler. It selects the in-memory or
// Postgres adapter from configuration.
func New(d Deps) *Handler {
	var repo Repository
	if d.Config.UseMockData || d.DB == nil {
		repo = NewMockRepository()
	} else {
		repo = NewGormRepository(d.DB)
	}

	limits := QuotaLimits{
		TextDaily:  d.Config.Quota.TextDaily,
		ImageDaily: d.Config.Quota.ImageDaily,
	}
	if limits.TextDaily <= 0 {
		limits.TextDaily = 50
	}
	if limits.ImageDaily <= 0 {
		limits.ImageDaily = 20
	}

	svc := NewService(repo, limits, d.Logger)
	return NewHandler(svc)
}
