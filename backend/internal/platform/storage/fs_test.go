package storage

import (
	"bytes"
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
)

// These tests exercise the filesystem adapter against a real temp directory
// (t.TempDir, auto-cleaned) — no network, no fixtures. The security-critical
// behaviour is the path-traversal guard and the atomic write.

func TestFSPutGetRoundTrip(t *testing.T) {
	ctx := context.Background()
	s, err := NewFS(t.TempDir())
	if err != nil {
		t.Fatalf("NewFS: %v", err)
	}
	want := []byte("re-encoded image bytes")
	if err := s.Put(ctx, "ab/asset.png", want); err != nil {
		t.Fatalf("Put: %v", err)
	}
	got, err := s.(Reader).Get(ctx, "ab/asset.png")
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if !bytes.Equal(got, want) {
		t.Fatalf("round trip: got %q, want %q", got, want)
	}
}

// The blob lands under the base dir with 0600 perms and no stray temp file is
// left behind after a successful write.
func TestFSPutIsPrivateAndClean(t *testing.T) {
	ctx := context.Background()
	base := t.TempDir()
	s, err := NewFS(base)
	if err != nil {
		t.Fatalf("NewFS: %v", err)
	}
	if err := s.Put(ctx, "cd/x.jpg", []byte("data")); err != nil {
		t.Fatalf("Put: %v", err)
	}

	info, err := os.Stat(filepath.Join(base, "cd", "x.jpg"))
	if err != nil {
		t.Fatalf("stat blob: %v", err)
	}
	if perm := info.Mode().Perm(); perm != 0o600 {
		t.Fatalf("blob perms: got %o, want 600", perm)
	}

	// No leftover temp files in the shard directory.
	entries, err := os.ReadDir(filepath.Join(base, "cd"))
	if err != nil {
		t.Fatalf("readdir: %v", err)
	}
	if len(entries) != 1 || entries[0].Name() != "x.jpg" {
		t.Fatalf("expected only the blob, got %v", entries)
	}
}

// A key that tries to climb out of the base dir is rejected and writes nothing.
func TestFSRejectsTraversal(t *testing.T) {
	ctx := context.Background()
	base := t.TempDir()
	s, err := NewFS(base)
	if err != nil {
		t.Fatalf("NewFS: %v", err)
	}
	for _, key := range []string{"../escape.png", "a/../../escape.png", "", "/etc/passwd"} {
		if err := s.Put(ctx, key, []byte("x")); err == nil {
			t.Fatalf("Put(%q): expected rejection, got nil", key)
		}
	}
	// Nothing escaped into the parent of the base dir.
	if _, err := os.Stat(filepath.Join(filepath.Dir(base), "escape.png")); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("traversal wrote outside base dir: %v", err)
	}
}

func TestFSGetMissingIsNotFound(t *testing.T) {
	s, err := NewFS(t.TempDir())
	if err != nil {
		t.Fatalf("NewFS: %v", err)
	}
	if _, err := s.(Reader).Get(context.Background(), "no/such.png"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("Get missing: want ErrNotFound, got %v", err)
	}
}

// Delete removes the blob and is idempotent (deleting a missing key is fine),
// which is what makes it safe as best-effort cleanup after a failed DB insert.
func TestFSDeleteIsIdempotent(t *testing.T) {
	ctx := context.Background()
	s, err := NewFS(t.TempDir())
	if err != nil {
		t.Fatalf("NewFS: %v", err)
	}
	if err := s.Put(ctx, "ef/y.png", []byte("data")); err != nil {
		t.Fatalf("Put: %v", err)
	}
	if err := s.Delete(ctx, "ef/y.png"); err != nil {
		t.Fatalf("Delete: %v", err)
	}
	if _, err := s.(Reader).Get(ctx, "ef/y.png"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("after Delete: want ErrNotFound, got %v", err)
	}
	// Deleting again is not an error.
	if err := s.Delete(ctx, "ef/y.png"); err != nil {
		t.Fatalf("Delete again: %v", err)
	}
}

// The in-memory adapter round-trips and copies bytes so a caller can't mutate
// stored data through a retained slice.
func TestMemoryStoreRoundTripAndCopies(t *testing.T) {
	ctx := context.Background()
	s := NewMemory()
	src := []byte("abc")
	if err := s.Put(ctx, "k", src); err != nil {
		t.Fatalf("Put: %v", err)
	}
	src[0] = 'z' // mutate caller's slice after Put

	got, err := s.(Reader).Get(ctx, "k")
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if string(got) != "abc" {
		t.Fatalf("stored bytes were aliased to caller's slice: got %q", got)
	}
	got[0] = 'Q' // mutate returned slice; store must be unaffected
	if again, _ := s.(Reader).Get(ctx, "k"); string(again) != "abc" {
		t.Fatalf("returned slice aliased the store: got %q", again)
	}
}
