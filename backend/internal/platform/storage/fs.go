package storage

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// fsStore is the filesystem Store adapter. It roots every blob under baseDir and
// refuses any key that would escape it. Writes are atomic: bytes go to a temp
// file in the destination directory, are flushed, then renamed into place, so a
// reader never sees a half-written blob and a crash mid-write leaves at most a
// stray temp file (never a corrupt blob at key).
type fsStore struct {
	baseDir string
}

// NewFS builds a filesystem-backed Store rooted at baseDir, creating the tree
// (0700) if absent. baseDir should live OUTSIDE any web root (PRD §6.8);
// config.validate enforces an absolute path when APP_ENV=production.
func NewFS(baseDir string) (Store, error) {
	abs, err := filepath.Abs(baseDir)
	if err != nil {
		return nil, fmt.Errorf("storage: resolve base dir: %w", err)
	}
	if err := os.MkdirAll(abs, 0o700); err != nil {
		return nil, fmt.Errorf("storage: create base dir: %w", err)
	}
	return &fsStore{baseDir: abs}, nil
}

// resolve maps an opaque key to an absolute path under baseDir, rejecting any key
// that escapes the root (via "..", an absolute path, etc.). This is the single
// security gate on WHERE bytes may land. filepath.Join applies Clean — collapsing
// any ".." — and the prefix check then rejects a key that climbed out.
func (s *fsStore) resolve(key string) (string, error) {
	if key == "" {
		return "", fmt.Errorf("storage: empty key")
	}
	rel := filepath.FromSlash(key)
	if filepath.IsAbs(rel) {
		return "", fmt.Errorf("storage: key %q must be relative", key)
	}
	full := filepath.Join(s.baseDir, rel)
	if full != s.baseDir && !strings.HasPrefix(full, s.baseDir+string(os.PathSeparator)) {
		return "", fmt.Errorf("storage: key %q escapes base dir", key)
	}
	return full, nil
}

func (s *fsStore) Put(_ context.Context, key string, data []byte) error {
	full, err := s.resolve(key)
	if err != nil {
		return err
	}
	dir := filepath.Dir(full)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return fmt.Errorf("storage: create dir: %w", err)
	}

	// Temp file in the SAME directory so the rename stays on one filesystem (a
	// cross-device rename would fall back to a non-atomic copy).
	tmp, err := os.CreateTemp(dir, ".tmp-*")
	if err != nil {
		return fmt.Errorf("storage: create temp: %w", err)
	}
	tmpName := tmp.Name()
	// Ensure the temp file never lingers on any error path. After a successful
	// rename it no longer exists, so this Remove is a harmless no-op.
	defer func() { _ = os.Remove(tmpName) }()

	if _, err := tmp.Write(data); err != nil {
		_ = tmp.Close()
		return fmt.Errorf("storage: write temp: %w", err)
	}
	if err := tmp.Sync(); err != nil {
		_ = tmp.Close()
		return fmt.Errorf("storage: sync temp: %w", err)
	}
	if err := tmp.Close(); err != nil {
		return fmt.Errorf("storage: close temp: %w", err)
	}
	if err := os.Chmod(tmpName, 0o600); err != nil {
		return fmt.Errorf("storage: chmod temp: %w", err)
	}
	if err := os.Rename(tmpName, full); err != nil {
		return fmt.Errorf("storage: rename into place: %w", err)
	}
	return nil
}

func (s *fsStore) Get(_ context.Context, key string) ([]byte, error) {
	full, err := s.resolve(key)
	if err != nil {
		return nil, err
	}
	// resolve() has already confirmed full is inside baseDir (path traversal and
	// absolute keys are rejected), so the variable path is safe here.
	data, err := os.ReadFile(full) //nolint:gosec // G304: full is validated by resolve() to stay within baseDir
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("storage: read: %w", err)
	}
	return data, nil
}

func (s *fsStore) Delete(_ context.Context, key string) error {
	full, err := s.resolve(key)
	if err != nil {
		return err
	}
	if err := os.Remove(full); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("storage: delete: %w", err)
	}
	return nil
}
