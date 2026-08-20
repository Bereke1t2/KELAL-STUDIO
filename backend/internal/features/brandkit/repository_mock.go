package brandkit

import (
	"context"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// mockRepository is the in-memory Repository adapter used when UseMockData=true
// and in unit tests. It is safe for concurrent use and mirrors the real
// adapter's contract: the same domain sentinel errors and the same timestamp
// semantics (created_at set once, updated_at bumped on every write). It stores
// values and returns copies so a caller can't mutate the store through a
// returned pointer.
type mockRepository struct {
	mu   sync.RWMutex
	kits map[uuid.UUID]models.BrandKit
}

// NewMockRepository builds an empty in-memory brand-kit repository.
func NewMockRepository() Repository {
	return &mockRepository{kits: make(map[uuid.UUID]models.BrandKit)}
}

func (m *mockRepository) FindByID(_ context.Context, id uuid.UUID) (*models.BrandKit, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	kit, ok := m.kits[id]
	if !ok {
		return nil, ErrBrandKitNotFound
	}
	return &kit, nil
}

func (m *mockRepository) Create(_ context.Context, kit *models.BrandKit) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Mimic the model's BeforeCreate hook so a caller that didn't pre-set an id
	// still gets a populated one.
	if kit.ID == uuid.Nil {
		kit.ID = uuid.New()
	}
	if _, exists := m.kits[kit.ID]; exists {
		return ErrBrandKitExists
	}
	now := time.Now()
	kit.CreatedAt = now
	kit.UpdatedAt = now
	m.kits[kit.ID] = *kit
	return nil
}

func (m *mockRepository) Update(_ context.Context, kit *models.BrandKit) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	prev, ok := m.kits[kit.ID]
	if !ok {
		return ErrBrandKitNotFound
	}
	// Preserve created_at (set once) and bump updated_at, exactly as GORM does.
	kit.CreatedAt = prev.CreatedAt
	kit.UpdatedAt = time.Now()
	m.kits[kit.ID] = *kit
	return nil
}
