// Package asset owns image upload — the logo/photo ingest behind brand kits and
// image generation (PRD §6.8). It is a STUB, and it is the HIGHEST-RISK surface
// in the backend: every byte is untrusted input.
//
// This endpoint is NOT in the mobile contract (openapi.yaml) yet — it is
// derived from the PRD; add it to the backend's own api/openapi.yaml when built.
//
// Non-negotiable hardening when this is built (PRD §6.8, §7.8) — the whole
// reason this is its own carefully-owned slice:
//   - Validate type by CONTENT (magic bytes), never by filename or the
//     client-sent Content-Type.
//   - RE-ENCODE every image through an image library (never store the original
//     bytes) to neutralize polyglots and embedded payloads.
//   - STRIP all metadata (EXIF/GPS) — models.Asset.StrippedMetadata records it.
//   - Enforce max bytes and min/max dimensions (config.AssetConfig) BEFORE
//     decoding, to bound decompression-bomb cost.
//   - Store OUTSIDE any web root; serve via signed/proxied URLs, never a raw
//     filesystem path.
//
// TODO(asset): implement by copying the auth feature's layout.
package asset

// Handler is the asset delivery adapter (stub).
type Handler struct{}

// New builds the stub handler. TODO(asset): take a Deps struct (a storage
// backend, DB, config.AssetConfig limits, Logger).
func New() *Handler { return &Handler{} }
