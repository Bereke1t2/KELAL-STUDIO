// Package moderation is the pre-generation content-safety gate (PRD §6.4). It
// is INTERNAL: it has no HTTP route of its own (nothing in the mobile contract).
// The generation feature calls it BEFORE any provider call, and on refusal maps
// the Decision to apperror.ModerationRefused (a plain-language reason, never a
// raw classifier code). It is a STUB that defines the seam generation depends on.
package moderation

import "context"

// Decision is the outcome of a moderation check. Reason is safe to show the
// user in their own language (PRD §6.4) — it is never a raw classifier label.
type Decision struct {
	Allowed bool
	Reason  string
}

// Checker screens input (and later output) before generation. Implementations
// MUST FAIL CLOSED: if the moderation backend is unavailable, refuse rather
// than let unmoderated content through (PRD §6.4). generation depends on this
// interface, never on a concrete moderation vendor.
type Checker interface {
	CheckText(ctx context.Context, text, lang string) (Decision, error)
}

// stubChecker fails closed: it refuses everything with an explicit reason, so
// wiring it into a real generation path cannot silently ship an unmoderated
// product. TODO(moderation): replace with a real classifier before beta.
type stubChecker struct{}

// NewStubChecker returns the fail-closed stub.
func NewStubChecker() Checker { return stubChecker{} }

func (stubChecker) CheckText(_ context.Context, _, _ string) (Decision, error) {
	return Decision{Allowed: false, Reason: "content moderation is not available yet"}, nil
}
