package provider

import (
	"context"
	"log"
	"time"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
)

// TextChain tries its providers in order until one succeeds, applying a
// per-provider timeout and emitting one Usage per attempt. This is what the
// generation feature actually holds — it never sees an individual provider.
type TextChain struct {
	providers []TextProvider
	timeout   time.Duration
	telemetry TelemetryFunc
}

// NewTextChain builds a chain. Order matters: providers are tried left to right.
func NewTextChain(timeout time.Duration, telemetry TelemetryFunc, providers ...TextProvider) *TextChain {
	return &TextChain{providers: providers, timeout: timeout, telemetry: telemetry}
}

// Providers returns the ordered provider names (for logging/diagnostics).
func (c *TextChain) Providers() []string {
	return names(len(c.providers), func(i int) string { return c.providers[i].Name() })
}

// GenerateText runs the failover chain. On total failure it returns a classified
// apperror (provider_timeout / malformed_output). The winning provider's model
// info is available to the caller via the emitted Usage (telemetry) for the
// GenerationRecord.
func (c *TextChain) GenerateText(ctx context.Context, req TextRequest) (TextResult, Meta, *apperror.Error) {
	if len(c.providers) == 0 {
		return TextResult{}, Meta{}, apperror.ProviderTimeout("no text providers configured")
	}
	var lastErr error
	for _, p := range c.providers {
		callCtx, cancel := context.WithTimeout(ctx, c.timeout)
		start := time.Now()
		res, err := p.GenerateText(callCtx, req)
		latency := time.Since(start).Milliseconds()
		cancel()

		model, version := p.Model()
		c.emit(Usage{Provider: p.Name(), Model: model, ModelVersion: version, LatencyMS: latency, Err: err})
		if err == nil {
			return res, Meta{Provider: p.Name(), Model: model, ModelVersion: version, LatencyMS: latency}, nil
		}
		// Log the failure before trying the next provider.
		log.Printf("text provider %q failed: %v", p.Name(), err)
		lastErr = err
	}
	return TextResult{}, Meta{}, classify(lastErr, "all text providers failed")
}

func (c *TextChain) emit(u Usage) {
	if c.telemetry != nil {
		c.telemetry(u)
	}
}

// ImageChain is the image-generation analogue of TextChain.
type ImageChain struct {
	providers []ImageProvider
	timeout   time.Duration
	telemetry TelemetryFunc
}

// NewImageChain builds an image chain. Order matters: providers are tried left
// to right.
func NewImageChain(timeout time.Duration, telemetry TelemetryFunc, providers ...ImageProvider) *ImageChain {
	return &ImageChain{providers: providers, timeout: timeout, telemetry: telemetry}
}

// Providers returns the ordered provider names (for logging/diagnostics).
func (c *ImageChain) Providers() []string {
	return names(len(c.providers), func(i int) string { return c.providers[i].Name() })
}

// GenerateImage runs the failover chain, returning the winning provider's Meta
// alongside the result. On total failure it returns a classified apperror.
func (c *ImageChain) GenerateImage(ctx context.Context, req ImageRequest) (ImageResult, Meta, *apperror.Error) {
	if len(c.providers) == 0 {
		return ImageResult{}, Meta{}, apperror.ProviderTimeout("no image providers configured")
	}
	var lastErr error
	for _, p := range c.providers {
		callCtx, cancel := context.WithTimeout(ctx, c.timeout)
		start := time.Now()
		res, err := p.GenerateImage(callCtx, req)
		latency := time.Since(start).Milliseconds()
		cancel()

		model, version := p.Model()
		c.emit(Usage{Provider: p.Name(), Model: model, ModelVersion: version, LatencyMS: latency, Err: err})
		if err == nil {
			return res, Meta{Provider: p.Name(), Model: model, ModelVersion: version, LatencyMS: latency}, nil
		}
		lastErr = err
	}
	return ImageResult{}, Meta{}, classify(lastErr, "all image providers failed")
}

func (c *ImageChain) emit(u Usage) {
	if c.telemetry != nil {
		c.telemetry(u)
	}
}

// Meta is the winning provider's identity, returned alongside a result so the
// caller can persist it on the GenerationRecord (PRD §10.5).
type Meta struct {
	Provider     string
	Model        string
	ModelVersion string
	LatencyMS    int64
}

func names(n int, at func(int) string) []string {
	out := make([]string, n)
	for i := 0; i < n; i++ {
		out[i] = at(i)
	}
	return out
}
