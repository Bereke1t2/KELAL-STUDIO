package quota

import (
	"context"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// mockRepository is the in-memory Repository adapter used when UseMockData=true
// and in unit tests. It is safe for concurrent use.
type mockRepository struct {
	mu      sync.RWMutex
	records map[string]*mockQuotaRow // key: "userID:period"
}

type mockQuotaRow struct {
	textUsed  int
	imageUsed int
}

// NewMockRepository builds an empty in-memory quota repository.
func NewMockRepository() Repository {
	return &mockRepository{records: make(map[string]*mockQuotaRow)}
}

func (m *mockRepository) UpsertAndCheck(_ context.Context, userID uuid.UUID, genType models.GenerationType) (bool, interface{}, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	period := time.Now().UTC().Format("2006-01-02")
	midnight := time.Now().UTC().Truncate(24 * time.Hour).Add(24 * time.Hour)
	key := userID.String() + ":" + period

	row, ok := m.records[key]
	if !ok {
		row = &mockQuotaRow{}
		m.records[key] = row
	}

	switch genType {
	case models.GenerationText:
		row.textUsed++
	case models.GenerationImage:
		row.imageUsed++
	}

	return false, midnight, nil
}

func (m *mockRepository) GetTodayUsage(_ context.Context, userID uuid.UUID) (int, int, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	period := time.Now().UTC().Format("2006-01-02")
	key := userID.String() + ":" + period

	row, ok := m.records[key]
	if !ok {
		return 0, 0, nil
	}
	return row.textUsed, row.imageUsed, nil
}
