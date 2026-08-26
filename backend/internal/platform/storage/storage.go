// Package storage is the shared blob-storage PRIMITIVE: a narrow Store port plus
// two adapters — a filesystem store and an in-memory store. It holds NO business
// logic. Callers (the asset feature today; image/video generation later) decide
// WHAT to store and under WHICH key; this package only persists opaque bytes.
//
// The design mirrors platform/email: a small interface with a deterministic
// in-memory default for tests and mock mode (the analogue of the dev LogSender)
// and a real filesystem adapter selected by the composition root. No object-store
// vendor is baked in; a bucket-backed adapter (S3/GCS) can be added behind Store
// later without touching callers.
//
// SECURITY: the bytes handled here are attacker-influenced (uploaded, then
// re-encoded, images). Adapters MUST keep them OUTSIDE any web root and MUST
// reject a key that escapes the configured root — path traversal (PRD §6.8/§7.8).
package storage

import (
	"context"
	"errors"
)

// ErrNotFound is returned by Reader.Get when no blob exists at the key.
var ErrNotFound = errors.New("storage: blob not found")

// Store persists and removes opaque blobs addressed by an opaque key. A key is a
// forward-slash-separated relative path (e.g. "ab/<uuid>.png"); adapters map it
// onto their medium and MUST reject any key that escapes their root. Callers pass
// already-hardened bytes — the store neither inspects nor transforms them.
//
// Implementations must be safe for concurrent use.
type Store interface {
	// Put writes data under key, overwriting any existing blob there. The write
	// is atomic where the medium allows it (no partial blob is ever observable at
	// key). It returns an error for an invalid/escaping key or an I/O failure.
	Put(ctx context.Context, key string, data []byte) error
	// Delete removes the blob at key. Deleting a missing key is NOT an error
	// (idempotent), so it is safe as best-effort cleanup after a failed write.
	Delete(ctx context.Context, key string) error
}

// Reader is an optional capability a Store may also provide: reading a blob back.
// It is kept separate from Store because the asset feature does not read blobs
// yet (there is no download route). Both bundled adapters implement it — tests
// use it to assert what was stored, and the forthcoming asset-serving route will
// read through it. A missing key returns ErrNotFound.
type Reader interface {
	Get(ctx context.Context, key string) ([]byte, error)
}
