package asset

import (
	"context"
	"sync"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// mockRepository is the in-memory Repository adapter used when UseMockData=true
// and in unit tests. It is safe for concurrent use and stores values (returning
// nothing by pointer), mirroring the real adapter's contract.
type mockRepository struct {
	mu     sync.RWMutex
	assets map[uuid.UUID]models.Asset
}

// NewMockRepository builds an empty in-memory asset repository.
func NewMockRepository() Repository {
	return &mockRepository{assets: make(map[uuid.UUID]models.Asset)}
}

func (m *mockRepository) Create(_ context.Context, a *models.Asset) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Mimic the model's BeforeCreate hook so a caller that didn't pre-set an id
	// still gets one (the service always pre-sets it).
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	m.assets[a.ID] = *a
	return nil
}
