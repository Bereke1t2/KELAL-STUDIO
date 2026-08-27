// Package factory builds provider chains from configuration. It lives in its
// own package (importing both provider and provider/stub) so the core provider
// package never imports its own stubs — that would be an import cycle. cmd/api
// calls these; features receive the finished *provider.TextChain / ImageChain.
package factory

import (
	"fmt"
	"time"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider/gemini"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider/stub"
)

// BuildTextChain constructs a text failover chain from an ordered list of
// provider names. Supported providers: "stub", "gemini". An empty order
// defaults to the stub.
func BuildTextChain(order []string, timeout time.Duration, telemetry provider.TelemetryFunc, cfg *config.ProviderConfig) (*provider.TextChain, error) {
	providers := make([]provider.TextProvider, 0, len(order))
	for _, name := range order {
		switch name {
		case "stub":
			providers = append(providers, stub.NewText())
		case "gemini":
			if cfg == nil || cfg.GeminiAPIKey == "" {
				return nil, fmt.Errorf("factory: text provider %q requires GEMINI_API_KEY to be set", name)
			}
			providers = append(providers, gemini.NewText(cfg.GeminiAPIKey))
		default:
			return nil, fmt.Errorf("factory: text provider %q is not implemented (supported: stub, gemini)", name)
		}
	}
	if len(providers) == 0 {
		providers = append(providers, stub.NewText())
	}
	return provider.NewTextChain(timeout, telemetry, providers...), nil
}

// BuildImageChain is the image-generation analogue of BuildTextChain.
func BuildImageChain(order []string, timeout time.Duration, telemetry provider.TelemetryFunc) (*provider.ImageChain, error) {
	providers := make([]provider.ImageProvider, 0, len(order))
	for _, name := range order {
		switch name {
		case "stub":
			providers = append(providers, stub.NewImage())
		default:
			return nil, fmt.Errorf("factory: image provider %q is not implemented (only %q ships today)", name, "stub")
		}
	}
	if len(providers) == 0 {
		providers = append(providers, stub.NewImage())
	}
	return provider.NewImageChain(timeout, telemetry, providers...), nil
}
