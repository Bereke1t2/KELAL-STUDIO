// Package generation owns AI content generation: text (PRD §6.2, §6.3), image
// (§6.5), and video (§6.5, §8.4), plus job status (§10.3). It is a STUB.
//
// Non-negotiable rules when this is built (see docs/ARCHITECTURE.md):
//   - NEVER call an AI provider directly. Every generation goes through
//     platform/provider (the failover chain), so a provider swap is config-only
//     and no API key ever leaves the server (PRD §1.1, §10.1, §7.8).
//   - Run the moderation check (internal moderation feature) and enforce quota
//     (quota feature) BEFORE any outbound provider call (PRD §6.4, §6.14).
//   - Persist a models.GenerationRecord per call (provider, model, cost,
//     latency) for telemetry and quota accounting.
//
// Flags this feature must carry:
//   - OQ-02: image generation accepts ONLY "1:1" and "4:5" (openapi enum);
//     "9:16" stays rejected until the PRD decision lands. Don't silently add it.
//   - §10.3: video is async — enqueue via platform/queue, return a Job (202),
//     and let cmd/worker process it. The queue broker is unspecified (in-proc
//     default).
//   - Contract-vs-PRD: the contract's Job exposes result_asset_id, but PRD §11
//     calls it result_generation_id (models.Job stores ResultGenerationRecordID).
//     Serve the contract field and reconcile when video gen is built.
//
// TODO(generation): implement by copying the auth feature's layout.
package generation

// Handler is the generation delivery adapter (stub).
type Handler struct{}

// New builds the stub handler. TODO(generation): take a Deps struct carrying
// the provider chains (*provider.TextChain / *provider.ImageChain), the queue,
// the moderation checker, the quota enforcer, DB, Config, and Logger.
func New() *Handler { return &Handler{} }
