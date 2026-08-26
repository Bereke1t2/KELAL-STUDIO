package storage

import (
	"context"
	"fmt"
	"sync"
)

// memStore is the in-memory Store adapter used in tests and when UseMockData is
// set (no disk writes in the fake data layer, matching the in-memory
// repositories). It is safe for concurrent use and copies data in and out so a
// caller cannot mutate stored bytes through a retained slice.
type memStore struct {
	mu    sync.RWMutex
	blobs map[string][]byte
}

// NewMemory builds an empty in-memory Store. It also satisfies Reader.
func NewMemory() Store {
	return &memStore{blobs: make(map[string][]byte)}
}

func (m *memStore) Put(_ context.Context, key string, data []byte) error {
	if key == "" {
		return fmt.Errorf("storage: empty key")
	}
	cp := make([]byte, len(data))
	copy(cp, data)

	m.mu.Lock()
	defer m.mu.Unlock()
	m.blobs[key] = cp
	return nil
}

func (m *memStore) Get(_ context.Context, key string) ([]byte, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	data, ok := m.blobs[key]
	if !ok {
		return nil, ErrNotFound
	}
	cp := make([]byte, len(data))
	copy(cp, data)
	return cp, nil
}

func (m *memStore) Delete(_ context.Context, key string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.blobs, key)
	return nil
}
