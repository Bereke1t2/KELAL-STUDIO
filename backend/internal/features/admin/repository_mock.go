package admin

import (
	"context"
	"sort"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// mockRepository is the in-memory Repository adapter used when UseMockData=true
// and in unit tests. It is safe for concurrent use. Because each feature's mock
// is isolated (there is no shared in-memory database), it holds its OWN copies of
// the rows admin reads — users, moderation flags, generation records — plus the
// audit log it writes. Tests, which live in this package, seed those maps
// directly and assert on auditLogs after a mutation.
type mockRepository struct {
	mu          sync.RWMutex
	users       map[uuid.UUID]models.User
	flags       map[uuid.UUID]models.ModerationFlag
	generations []models.GenerationRecord
	auditLogs   []models.AdminAuditLog
}

// NewMockRepository builds an empty in-memory admin repository.
func NewMockRepository() Repository { return newMockRepository() }

// newMockRepository returns the concrete mock so in-package tests can seed its
// maps and inspect the recorded audit log without going through the interface.
func newMockRepository() *mockRepository {
	return &mockRepository{
		users: make(map[uuid.UUID]models.User),
		flags: make(map[uuid.UUID]models.ModerationFlag),
	}
}

func (m *mockRepository) UsageSummary(_ context.Context) (UsageSummary, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	s := UsageSummary{
		TotalUsers:       int64(len(m.users)),
		TotalGenerations: int64(len(m.generations)),
		TotalFlags:       int64(len(m.flags)),
	}
	for _, g := range m.generations {
		switch g.Type {
		case models.GenerationText:
			s.TextGenerations++
		case models.GenerationImage:
			s.ImageGenerations++
		case models.GenerationVideo:
			s.VideoGenerations++
		}
	}
	for _, f := range m.flags {
		if f.ReviewedAt == nil {
			s.PendingFlags++
		}
	}
	return s, nil
}

func (m *mockRepository) ListFlags(_ context.Context, onlyPending bool) ([]models.ModerationFlag, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	out := make([]models.ModerationFlag, 0, len(m.flags))
	for _, f := range m.flags {
		if onlyPending && f.ReviewedAt != nil {
			continue
		}
		out = append(out, f)
	}
	// Newest-first, matching the GORM adapter's ORDER BY created_at DESC. Ties are
	// broken by id so the order is deterministic (map iteration order is random).
	sort.Slice(out, func(i, j int) bool {
		if out[i].CreatedAt.Equal(out[j].CreatedAt) {
			return out[i].ID.String() > out[j].ID.String()
		}
		return out[i].CreatedAt.After(out[j].CreatedAt)
	})
	return out, nil
}

func (m *mockRepository) FindFlagByID(_ context.Context, id uuid.UUID) (*models.ModerationFlag, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	f, ok := m.flags[id]
	if !ok {
		return nil, ErrFlagNotFound
	}
	return &f, nil
}

func (m *mockRepository) ReviewFlag(_ context.Context, flag *models.ModerationFlag, audit *models.AdminAuditLog) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	stored, ok := m.flags[flag.ID]
	if !ok {
		return ErrFlagNotFound
	}
	// Mirror the GORM adapter's conditional claim: the stored row (not the
	// caller's possibly-stale copy) decides whether it's still unreviewed, so two
	// callers racing past the service pre-check can't both win.
	if stored.ReviewedAt != nil {
		return ErrFlagAlreadyReviewed
	}
	m.flags[flag.ID] = *flag
	m.appendAudit(audit)
	return nil
}

func (m *mockRepository) FindUserByID(_ context.Context, id uuid.UUID) (*models.User, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	u, ok := m.users[id]
	if !ok {
		return nil, ErrUserNotFound
	}
	return &u, nil
}

func (m *mockRepository) SetUserLimits(_ context.Context, user *models.User, audit *models.AdminAuditLog) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	prev, ok := m.users[user.ID]
	if !ok {
		return ErrUserNotFound
	}
	// Preserve created_at (set once) and bump updated_at, exactly as GORM does.
	user.CreatedAt = prev.CreatedAt
	user.UpdatedAt = time.Now()
	m.users[user.ID] = *user
	m.appendAudit(audit)
	return nil
}

// appendAudit mimics the model's BeforeCreate hook (assign an id if unset) and
// records the row. The caller must hold m.mu.
func (m *mockRepository) appendAudit(audit *models.AdminAuditLog) {
	if audit.ID == uuid.Nil {
		audit.ID = uuid.New()
	}
	m.auditLogs = append(m.auditLogs, *audit)
}
