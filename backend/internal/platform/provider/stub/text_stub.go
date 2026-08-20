// Package stub holds deterministic, dependency-free fake providers. They are
// the ONLY provider implementations that ship (OQ-20: no primary AI model has
// been chosen). They let the full generation flow — quota check, moderation,
// provider chain, telemetry, persistence — run end-to-end today, and give tests
// a provider with no network. Real providers live beside these later.
package stub

import (
	"context"
	"fmt"
	"strings"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider"
)

// Text is a deterministic text provider.
type Text struct{}

// NewText builds the stub text provider.
func NewText() *Text { return &Text{} }

// Name identifies this provider in telemetry and the failover chain.
func (*Text) Name() string { return "stub" }

// Model returns the stub's model name and version.
func (*Text) Model() (model, version string) { return "stub-text", "v0" }

// GenerateText returns canned bilingual copy derived from the request, so the
// output is stable for a given input (useful for tests and cache-key checks).
func (*Text) GenerateText(ctx context.Context, req provider.TextRequest) (provider.TextResult, error) {
	if err := ctx.Err(); err != nil {
		return provider.TextResult{}, err
	}
	idea := strings.TrimSpace(req.InputText)
	if idea == "" {
		idea = "your product"
	}
	platform := req.Platform
	if platform == "" {
		platform = "social"
	}
	return provider.TextResult{
		CaptionEN:    fmt.Sprintf("Discover %s — made for you. (stub caption for %s)", idea, platform),
		CaptionAM:    fmt.Sprintf("%s ን ያግኙ — ለእርስዎ የተዘጋጀ። (stub)", idea),
		CallToAction: "Order today!",
		Hashtags: []string{
			"#kelal", "#" + safeTag(platform), "#ethiopia", "#smallbusiness", "#madewithkelal",
		},
	}, nil
}

// safeTag reduces an arbitrary string to a hashtag-safe token.
func safeTag(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	var b strings.Builder
	for _, r := range s {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
		}
	}
	if b.Len() == 0 {
		return "post"
	}
	return b.String()
}
