package generation

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
	records []models.GenerationRecord
}

// NewMockRepository builds an empty in-memory generation repository.
func NewMockRepository() Repository {
	return &mockRepository{}
}

func (m *mockRepository) CreateGenerationRecord(_ context.Context, r *models.GenerationRecord) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if r.ID == uuid.Nil {
		r.ID = uuid.New()
	}
	if r.CreatedAt.IsZero() {
		r.CreatedAt = time.Now()
	}
	m.records = append(m.records, *r)
	return nil
}

func (m *mockRepository) FindGenerationRecordByInputHash(_ context.Context, userID uuid.UUID, inputHash string) (*models.GenerationRecord, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	if inputHash == "" {
		return nil, ErrGenerationRecordNotFound
	}
	// Return the most recent match.
	var latest *models.GenerationRecord
	for i := range m.records {
		r := &m.records[i]
		if r.UserID == userID && r.InputHash == inputHash {
			if latest == nil || r.CreatedAt.After(latest.CreatedAt) {
				latest = r
			}
		}
	}
	if latest == nil {
		return nil, ErrGenerationRecordNotFound
	}
_copy := *latest
	return &_copy, nil
}

func (m *mockRepository) CountTodayGenerations(_ context.Context, userID uuid.UUID, genType models.GenerationType) (int64, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	today := time.Now().UTC().Truncate(24 * time.Hour)
	var count int64
	for _, r := range m.records {
		if r.UserID == userID && r.Type == genType && !r.CreatedAt.Before(today) {
			count++
		}
	}
	return count, nil
}
