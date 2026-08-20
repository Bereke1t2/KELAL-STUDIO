// Package hashtag is the hashtag bank (PRD §6.3): a curated, platform-aware
// source of hashtags that augments generated captions. It is INTERNAL — no HTTP
// route of its own; the generation feature consumes it. It is a STUB defining
// the seam generation depends on.
//
// This is distinct from the provider's model-generated hashtags: the bank is a
// deterministic, human-curated set (brand-safe, locally relevant) that can be
// merged with or override model output.
package hashtag

import (
	"context"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
)

// Bank supplies platform-appropriate hashtags for a topic. n is the desired
// count (the contract's GenerateTextResponse allows 5–8 hashtags).
type Bank interface {
	Suggest(ctx context.Context, platform, topic string, n int) ([]string, error)
}

// stubBank is not implemented yet; it returns a not_implemented error so a
// premature wire fails loudly rather than shipping empty hashtags silently.
// TODO(hashtag): implement a curated bank keyed by platform + topic.
type stubBank struct{}

// NewStubBank returns the stub hashtag bank.
func NewStubBank() Bank { return stubBank{} }

func (stubBank) Suggest(_ context.Context, _, _ string, _ int) ([]string, error) {
	return nil, apperror.NotImplemented("hashtag bank")
}
