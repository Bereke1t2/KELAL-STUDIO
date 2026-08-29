package stub

import (
	"bytes"
	"context"
	"fmt"
	"image"
	"image/color"
	"image/gif"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider"
)

// Video is a deterministic video provider: it renders a solid-color GIF as a
// placeholder. Real bytes, no network — the asset feature can store it exactly
// as it would a real provider's output (PRD §6.8).
type Video struct{}

// NewVideo builds the stub video provider.
func NewVideo() *Video { return &Video{} }

// Name identifies this provider in telemetry and the failover chain.
func (*Video) Name() string { return "stub" }

// Model returns the stub's model name and version.
func (*Video) Model() (model, version string) { return "stub-video", "v0" }

// GenerateVideo renders a deterministic solid-color GIF as a placeholder.
func (*Video) GenerateVideo(ctx context.Context, req provider.VideoRequest) (provider.VideoResult, error) {
	if err := ctx.Err(); err != nil {
		return provider.VideoResult{}, err
	}
	w, h := videoDims(req.AspectRatio)

	// Create a single-frame GIF as a minimal valid video placeholder.
	draw := image.NewPaletted(image.Rect(0, 0, w, h), color.Palette{
		color.RGBA{R: 0x1E, G: 0x88, B: 0xE5, A: 0xFF},
	})
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			draw.SetColorIndex(x, y, 0)
		}
	}

	var buf bytes.Buffer
	if err := gif.Encode(&buf, draw, nil); err != nil {
		return provider.VideoResult{}, fmt.Errorf("%w: gif encode: %v", provider.ErrMalformedOutput, err)
	}

	return provider.VideoResult{
		VideoBytes: buf.Bytes(),
		MimeType:   "image/gif",
		Width:      w,
		Height:     h,
	}, nil
}

func videoDims(aspectRatio string) (w, h int) {
	switch aspectRatio {
	case "16:9":
		return 1280, 720
	default: // "9:16"
		return 720, 1280
	}
}
