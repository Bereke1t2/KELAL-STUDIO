package stub

import (
	"bytes"
	"context"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/png"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider"
)

// Image is a deterministic image provider: it renders a solid-color PNG at the
// requested aspect ratio. Real bytes, no network — the asset feature can
// re-encode/store it exactly as it would a real provider's output (PRD §6.8).
type Image struct{}

// NewImage builds the stub image provider.
func NewImage() *Image { return &Image{} }

// Name identifies this provider in telemetry and the failover chain.
func (*Image) Name() string { return "stub" }

// Model returns the stub's model name and version.
func (*Image) Model() (model, version string) { return "stub-image", "v0" }

// GenerateImage renders a deterministic solid-color PNG at the requested ratio.
func (*Image) GenerateImage(ctx context.Context, req provider.ImageRequest) (provider.ImageResult, error) {
	if err := ctx.Err(); err != nil {
		return provider.ImageResult{}, err
	}
	w, h := dimsFor(req.AspectRatio)

	img := image.NewRGBA(image.Rect(0, 0, w, h))
	// Kelal blue; deterministic so the output is stable per request.
	draw.Draw(img, img.Bounds(), &image.Uniform{C: color.RGBA{R: 0x1E, G: 0x88, B: 0xE5, A: 0xFF}}, image.Point{}, draw.Src)

	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return provider.ImageResult{}, fmt.Errorf("%w: png encode: %v", provider.ErrMalformedOutput, err)
	}
	return provider.ImageResult{
		ImageBytes: buf.Bytes(),
		MimeType:   "image/png",
		Width:      w,
		Height:     h,
	}, nil
}

// dimsFor maps the two supported aspect ratios to pixel dimensions. Only "1:1"
// and "4:5" exist (OQ-02); anything else falls back to square — the image
// feature is what actually REJECTS an unsupported ratio before it gets here.
func dimsFor(aspectRatio string) (w, h int) {
	switch aspectRatio {
	case "4:5":
		return 1024, 1280
	default: // "1:1"
		return 1024, 1024
	}
}
