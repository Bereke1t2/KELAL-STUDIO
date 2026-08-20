// Package provider is the Provider Abstraction Layer (PRD §10.1) — the single,
// load-bearing rule of this backend: NO feature code ever calls an external AI
// provider directly. Features depend on the TextProvider / ImageProvider
// interfaces here and are handed a failover Chain, so swapping, reordering, or
// adding providers never touches feature code.
//
// The layer owns: an ordered failover chain, a per-provider timeout, per-call
// usage telemetry (which feeds models.GenerationRecord), and a typed error
// taxonomy (errors.go) so callers get apperror codes, not raw provider errors.
//
// OQ-20: no primary AI model has been selected, so the only implementation that
// ships is the deterministic stub (subpackage ./stub). Real providers
// (Nemotron/Gemini for text, FLUX/Pollinations for image — PRD §1.1) are wired
// by adding an implementation and listing its name in the config order.
package provider

import "context"

// ── Normalized request/response types ───────────────────────────────────────
// These are the provider-agnostic shapes. Handlers translate feature DTOs into
// these; providers translate these into their own API calls and back.

// TextRequest is a normalized caption-generation request (PRD §6.2).
type TextRequest struct {
	InputText string // the user's raw idea
	InputLang string // "en" | "am" | "auto"
	Platform  string // "instagram" | "tiktok" | "telegram"
	BrandName string // flattened brand context (optional)
	Tone      string // brand tone of voice (optional)
}

// TextResult is the normalized bilingual caption output (PRD §6.2, matches
// GenerateTextResponse in the contract).
type TextResult struct {
	CaptionEN    string
	CaptionAM    string
	CallToAction string
	Hashtags     []string
}

// ImageRequest is a normalized image-generation request (PRD §6.5).
type ImageRequest struct {
	CaptionEN   string
	AspectRatio string // "1:1" | "4:5" — see OQ-02; 9:16 is NOT accepted
	BrandName   string
}

// ImageResult is the normalized image output. Providers return raw bytes; the
// asset feature is responsible for re-encoding, metadata stripping, and storage
// (PRD §6.8) — the provider layer does not touch storage.
type ImageResult struct {
	ImageBytes []byte
	MimeType   string
	Width      int
	Height     int
}

// ── Provider interfaces ──────────────────────────────────────────────────────

// TextProvider is one text-generation backend (a real model, or the stub).
type TextProvider interface {
	// Name identifies the provider in telemetry + GenerationRecord.Provider.
	Name() string
	// Model reports the model + version this provider used, for the record.
	Model() (model, version string)
	// GenerateText must honor ctx cancellation/timeout. It returns a provider
	// sentinel error (see errors.go) on failure so the chain can classify it.
	GenerateText(ctx context.Context, req TextRequest) (TextResult, error)
}

// ImageProvider is one image-generation backend.
type ImageProvider interface {
	Name() string
	Model() (model, version string)
	GenerateImage(ctx context.Context, req ImageRequest) (ImageResult, error)
}

// ── Telemetry ────────────────────────────────────────────────────────────────

// Usage is emitted once per provider CALL (success or failure) — the raw
// material for GenerationRecord + the global daily spend ceiling (PRD §12).
type Usage struct {
	Provider     string
	Model        string
	ModelVersion string
	LatencyMS    int64
	Cost         float64
	Err          error // nil on success
}

// TelemetryFunc receives every Usage. Wiring it to persistence/metrics is the
// caller's job; the chain just calls it. A nil TelemetryFunc is a no-op.
type TelemetryFunc func(Usage)
