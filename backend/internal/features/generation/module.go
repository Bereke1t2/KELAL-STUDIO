package generation

import (
	"log/slog"

	"gorm.io/gorm"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/hashtag"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/moderation"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/quota"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/queue"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/storage"
)

// Deps are everything the generation feature needs from the composition root
// (cmd/api). Passing them in — rather than reaching for globals — is what lets
// tests construct the feature with a mock repo and fake providers.
type Deps struct {
	DB         *gorm.DB // may be nil when Config.UseMockData is true
	Config     *config.Config
	Logger     *slog.Logger
	TextChain  *provider.TextChain
	ImageChain *provider.ImageChain
	VideoChain *provider.VideoChain
	Moderation moderation.Checker
	Quota      *quota.Service
	Hashtag    hashtag.Bank
	Queue      queue.Queue
	Store      storage.Store
}

// Module holds the wired Handler and Service. The Service is exposed so
// cmd/api can register ProcessVideoJob as the queue consumer handler.
type Module struct {
	Handler *Handler
	Service *Service
}

// New wires the feature and returns its Module. It selects the in-memory or
// Postgres adapter from configuration — the backend analogue of the mobile
// app's per-feature @module gated on Env.useMockData.
func New(d Deps) Module {
	var repo Repository
	if d.Config.UseMockData || d.DB == nil {
		repo = NewMockRepository()
	} else {
		repo = NewGormRepository(d.DB)
	}

	svc := NewService(repo, d.TextChain, d.ImageChain, d.VideoChain, d.Moderation, d.Quota, d.Hashtag, d.Queue, d.Store, d.Logger)
	h := NewHandler(svc)
	return Module{Handler: h, Service: svc}
}
