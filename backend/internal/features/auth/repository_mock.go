package auth

import (
	"context"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// mockRepository is the in-memory Repository adapter used when UseMockData=true
// and in unit tests. It is safe for concurrent use and mirrors the real
// adapter's contract: same domain sentinel errors, same soft-delete semantics
// (a deleted user's email stays reserved, exactly as the DB's unique index
// keeps it after a soft delete). It stores values and returns copies so a
// caller can't mutate the store through a returned pointer.
type mockRepository struct {
	mu        sync.RWMutex
	usersByID map[uuid.UUID]models.User
	emailToID map[string]uuid.UUID
	deleted   map[uuid.UUID]bool
	tokens    map[uuid.UUID]models.RefreshToken
}

// NewMockRepository builds an empty in-memory auth repository.
func NewMockRepository() Repository {
	return &mockRepository{
		usersByID: make(map[uuid.UUID]models.User),
		emailToID: make(map[string]uuid.UUID),
		deleted:   make(map[uuid.UUID]bool),
		tokens:    make(map[uuid.UUID]models.RefreshToken),
	}
}

func (m *mockRepository) CreateUser(_ context.Context, u *models.User) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, exists := m.emailToID[u.Email]; exists {
		return ErrEmailTaken
	}
	// Mimic the model's BeforeCreate hook so the caller sees a populated id.
	if u.ID == uuid.Nil {
		u.ID = uuid.New()
	}
	now := time.Now()
	u.CreatedAt = now
	u.UpdatedAt = now

	m.usersByID[u.ID] = *u
	m.emailToID[u.Email] = u.ID
	return nil
}

func (m *mockRepository) FindUserByEmail(_ context.Context, email string) (*models.User, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	id, ok := m.emailToID[email]
	if !ok || m.deleted[id] {
		return nil, ErrUserNotFound
	}
	u := m.usersByID[id]
	return &u, nil
}

func (m *mockRepository) FindUserByID(_ context.Context, id uuid.UUID) (*models.User, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	u, ok := m.usersByID[id]
	if !ok || m.deleted[id] {
		return nil, ErrUserNotFound
	}
	return &u, nil
}

func (m *mockRepository) UpdateUserPassword(_ context.Context, id uuid.UUID, passwordHash string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	u, ok := m.usersByID[id]
	if !ok || m.deleted[id] {
		return ErrUserNotFound
	}
	u.PasswordHash = passwordHash
	u.UpdatedAt = time.Now()
	m.usersByID[id] = u
	return nil
}

func (m *mockRepository) SoftDeleteUser(_ context.Context, id uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, ok := m.usersByID[id]; !ok || m.deleted[id] {
		return ErrUserNotFound
	}
	m.deleted[id] = true
	return nil
}

func (m *mockRepository) CreateRefreshToken(_ context.Context, rt *models.RefreshToken) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if rt.ID == uuid.Nil {
		rt.ID = uuid.New()
	}
	rt.CreatedAt = time.Now()
	m.tokens[rt.ID] = *rt
	return nil
}

func (m *mockRepository) FindRefreshTokenByID(_ context.Context, id uuid.UUID) (*models.RefreshToken, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	rt, ok := m.tokens[id]
	if !ok {
		return nil, ErrRefreshTokenNotFound
	}
	return &rt, nil
}

func (m *mockRepository) RevokeRefreshToken(_ context.Context, id uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	rt, ok := m.tokens[id]
	if !ok {
		return nil // idempotent: nothing to revoke
	}
	if rt.RevokedAt == nil {
		now := time.Now()
		rt.RevokedAt = &now
		m.tokens[id] = rt
	}
	return nil
}

func (m *mockRepository) RevokeAllUserRefreshTokens(_ context.Context, userID uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	now := time.Now()
	for id, rt := range m.tokens {
		if rt.UserID == userID && rt.RevokedAt == nil {
			rt.RevokedAt = &now
			m.tokens[id] = rt
		}
	}
	return nil
}
