package reminder

import (
	"log/slog"

	"gorm.io/gorm"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
)

// Deps are everything the reminder feature needs from the composition root.
type Deps struct {
	DB     *gorm.DB // may be nil when Config.UseMockData is true
	Config *config.Config
	Logger *slog.Logger
}

// Module holds the wired Handler and Service. The Service is exposed so
// cmd/api can call FireDueReminders from the background scheduler.
type Module struct {
	Handler *Handler
	Service *Service
}

// New wires the feature and returns its Module.
func New(d Deps) Module {
	var repo Repository
	if d.Config.UseMockData || d.DB == nil {
		repo = NewMockRepository()
	} else {
		repo = NewGormRepository(d.DB)
	}

	svc := NewService(repo, d.Logger)
	h := NewHandler(svc)
	return Module{Handler: h, Service: svc}
}
