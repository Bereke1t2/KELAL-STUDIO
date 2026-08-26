// Package asset owns image upload — the logo/photo ingest behind brand kits and
// image generation (PRD §6.8). It is the HIGHEST-RISK surface in the backend:
// every uploaded byte is untrusted input, so the upload pipeline is deliberately
// strict (see service.go). Its layout copies the auth/brandkit reference:
//
//	handler.go / dto.go / routes.go    → delivery (gin only lives here)
//	service.go                         → the hardening pipeline; returns (T, *apperror.Error)
//	domain.go                          → the Repository PORT + domain types
//	repository.go / repository_mock.go → adapters that persist the asset ROW
//	module.go                          → wiring; picks the mock or real adapter
//
// Hardening applied to EVERY upload (PRD §6.8, §7.8) — the reason this is its own
// carefully-owned slice:
//   - Type is decided by CONTENT (magic bytes) and confirmed by the decoder,
//     never by the filename or the client-sent Content-Type.
//   - Only JPEG and PNG are accepted (the two stdlib decoders registered here).
//   - Byte-size and min/max dimension limits are enforced BEFORE the full decode
//     (dimensions come from the header), bounding decompression-bomb cost.
//   - Every image is RE-ENCODED from its decoded pixels, never stored as the
//     original bytes — this neutralizes polyglots/appended payloads and strips
//     all EXIF/GPS/ICC metadata (models.Asset.StrippedMetadata records it).
//   - Bytes are stored via platform/storage OUTSIDE any web root; the row keeps
//     only an opaque StorageRef, never a client-reachable path.
package asset

import (
	"context"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// Repository is the port the asset service depends on for persistence of the
// asset ROW; the blob bytes go through platform/storage, not here. It is declared
// on the CONSUMER side so the feature never imports a concrete data layer — two
// adapters implement it: repository.go (GORM/Postgres) and repository_mock.go
// (in-memory).
type Repository interface {
	// Create persists a new asset row. The id is a freshly-generated uuid, so
	// there is no not-found or duplicate case to model here; a driver error is
	// returned verbatim for the service to wrap as an internal error.
	Create(ctx context.Context, a *models.Asset) error
}
