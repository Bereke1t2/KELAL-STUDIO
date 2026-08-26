// Package hashtag is the hashtag bank (PRD §6.3): a curated, platform-aware
// source of hashtags that augments generated captions. It is INTERNAL — no HTTP
// route of its own; the generation feature consumes it.
//
// This is distinct from the provider's model-generated hashtags: the bank is a
// deterministic, human-curated set (brand-safe, locally relevant) that can be
// merged with or override model output.
package hashtag

import "context"

// Bank supplies platform-appropriate hashtags for a topic. n is the desired
// count (the contract's GenerateTextResponse allows 5–8 hashtags).
type Bank interface {
	Suggest(ctx context.Context, platform, topic string, n int) ([]string, error)
}

// NewBank returns the curated hashtag bank. This is the default implementation
// used by the generation feature.
func NewBank() Bank {
	return NewCuratedBank()
}
