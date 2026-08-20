// Package brandkit owns brand-kit retrieval and update (PRD §6.8). It is built
// by copying the auth reference feature's layout:
//
//	handler.go / dto.go / routes.go   → delivery (gin only lives here)
//	service.go                        → use cases; returns (T, *apperror.Error)
//	domain.go                         → the Repository PORT + domain types/errors
//	repository.go / repository_mock.go → adapters that implement the port
//	module.go                         → wiring; picks the mock or real adapter
//
// A brand kit is owned by exactly one user. Every use case is owner-scoped: a
// caller can only ever read or write their OWN kit (PRD §6.8). The logo is a
// reference (logo_asset_id → models.Asset, owned by the asset feature); image
// bytes are never stored on the kit itself.
package brandkit

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// Domain sentinel errors. The repository returns these; the service maps each to
// an *apperror.Error. Declaring them here (not in the adapters) keeps the GORM
// and mock adapters agreeing on the vocabulary the service branches on with
// errors.Is — exactly as the auth feature does.
var (
	// ErrBrandKitNotFound is returned when no brand kit matches an id.
	ErrBrandKitNotFound = errors.New("brandkit: brand kit not found")
	// ErrBrandKitExists is returned by Create when a kit with that id already
	// exists (the primary key is the source of truth, not a prior lookup — that
	// would be a race). It only surfaces on the narrow create-time id collision.
	ErrBrandKitExists = errors.New("brandkit: brand kit already exists")
)

// Input carries the mutable fields of a brand kit for a create/update. It is a
// domain type (no gin/json tags) so the service never depends on the delivery
// DTO — the handler maps its request body into this. Server-managed fields (id,
// user_id, timestamps) are deliberately absent: they are never client-supplied.
type Input struct {
	BrandName         string
	LogoAssetID       *uuid.UUID
	PrimaryColorHex   string
	SecondaryColorHex string
	ToneOfVoice       string
	ContactInfo       string
}

// Repository is the port the brand-kit service depends on, declared here on the
// CONSUMER side so the feature never imports a concrete data layer. Two adapters
// implement it: repository.go (GORM/Postgres) and repository_mock.go
// (in-memory). Implementations MUST return the domain sentinel errors above for
// the not-found / duplicate cases — the service relies on errors.Is against them.
//
// The port is intentionally ownership-agnostic (it addresses kits by id only).
// The owner check lives in the service, where the authenticated caller is known
// — keeping authorization policy out of the storage adapter.
type Repository interface {
	// FindByID returns the brand kit with this id, or ErrBrandKitNotFound.
	FindByID(ctx context.Context, id uuid.UUID) (*models.BrandKit, error)
	// Create persists a new brand kit. It returns ErrBrandKitExists if a kit
	// with that id already exists.
	Create(ctx context.Context, kit *models.BrandKit) error
	// Update persists changes to an existing kit (matched by id), returning
	// ErrBrandKitNotFound if there was nothing to update.
	Update(ctx context.Context, kit *models.BrandKit) error
}
