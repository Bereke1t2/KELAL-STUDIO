package generation

import (
	"log/slog"

	"gorm.io/gorm"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/hashtag"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/moderation"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/features/quota"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider"
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
	Moderation moderation.Checker
	Quota      *quota.Service
	Hashtag    hashtag.Bank
}

// New wires the feature and returns its Handler. It selects the in-memory or
// Postgres adapter from configuration — the backend analogue of the mobile
// app's per-feature @module gated on Env.useMockData.
func New(d Deps) *Handler {
	var repo Repository
	if d.Config.UseMockData || d.DB == nil {
		repo = NewMockRepository()
	} else {
		repo = NewGormRepository(d.DB)
	}

	svc := NewService(repo, d.TextChain, d.ImageChain, d.Moderation, d.Quota, d.Hashtag, d.Logger)
	return NewHandler(svc)
}
