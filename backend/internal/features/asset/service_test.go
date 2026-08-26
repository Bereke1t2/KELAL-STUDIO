package asset

import (
	"bytes"
	"context"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"io"
	"log/slog"
	"strings"
	"testing"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/storage"
)

// These tests run entirely on the in-memory row repo + in-memory blob store — no
// Postgres, no filesystem. They exercise the hardening pipeline directly: valid
// images are accepted, re-encoded, and retrievable; every malformed or
// out-of-policy input is a validation_error (400). The metadata-strip test is the
// load-bearing one — it proves an embedded EXIF payload does NOT survive.

func discardLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

// defaultAssetCfg is a permissive config: 10 MiB, 200–4096px. Tests that probe a
// specific limit override just that field.
func defaultAssetCfg() config.AssetConfig {
	return config.AssetConfig{
		StorageDir:   "", // unused — tests inject an in-memory store
		MaxBytes:     10 * 1024 * 1024,
		MaxDimension: 4096,
		MinDimension: 200,
	}
}

// newTestService builds the service on the mock row repo and an in-memory blob
// store, returning both so a test can read the stored bytes back via the store's
// optional Reader.
func newTestService(cfg config.AssetConfig) (*Service, storage.Store) {
	store := storage.NewMemory()
	svc := NewService(NewMockRepository(), store, cfg, discardLogger())
	return svc, store
}

// gradientImage builds a w×h image with varying pixels, so JPEG encoding
// produces real (non-degenerate) content and dimensions are exact.
func gradientImage(w, h int) image.Image {
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			img.Set(x, y, color.RGBA{R: uint8(x % 256), G: uint8(y % 256), B: uint8((x + y) % 256), A: 255})
		}
	}
	return img
}

func makePNG(t *testing.T, w, h int) []byte {
	t.Helper()
	var buf bytes.Buffer
	if err := png.Encode(&buf, gradientImage(w, h)); err != nil {
		t.Fatalf("png.Encode: %v", err)
	}
	return buf.Bytes()
}

func makeJPEG(t *testing.T, w, h int) []byte {
	t.Helper()
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, gradientImage(w, h), &jpeg.Options{Quality: 90}); err != nil {
		t.Fatalf("jpeg.Encode: %v", err)
	}
	return buf.Bytes()
}

// storedBytes reads a blob back out of the in-memory store via its Reader.
func storedBytes(t *testing.T, store storage.Store, key string) []byte {
	t.Helper()
	r, ok := store.(storage.Reader)
	if !ok {
		t.Fatalf("store %T does not implement storage.Reader", store)
	}
	b, err := r.Get(context.Background(), key)
	if err != nil {
		t.Fatalf("store.Get(%q): %v", key, err)
	}
	return b
}

func TestUploadPNGAccepted(t *testing.T) {
	ctx := context.Background()
	svc, store := newTestService(defaultAssetCfg())
	owner := uuid.New()

	asset, aerr := svc.Upload(ctx, owner, makePNG(t, 256, 256))
	if aerr != nil {
		t.Fatalf("Upload valid PNG: unexpected error %v", aerr)
	}
	if asset.OwnerUserID != owner {
		t.Fatalf("owner: want %s, got %s", owner, asset.OwnerUserID)
	}
	if asset.Width != 256 || asset.Height != 256 {
		t.Fatalf("dimensions: want 256x256, got %dx%d", asset.Width, asset.Height)
	}
	if asset.MimeType != "image/png" {
		t.Fatalf("mime: want image/png, got %s", asset.MimeType)
	}
	if !asset.StrippedMetadata {
		t.Fatal("StrippedMetadata: want true")
	}
	if asset.ID == uuid.Nil {
		t.Fatal("ID: want a generated uuid, got nil")
	}
	if !strings.HasSuffix(asset.StorageRef, ".png") {
		t.Fatalf("StorageRef: want a .png key, got %q", asset.StorageRef)
	}

	// The stored blob must be present and decode as a PNG.
	blob := storedBytes(t, store, asset.StorageRef)
	if _, format, err := image.Decode(bytes.NewReader(blob)); err != nil || format != "png" {
		t.Fatalf("stored blob: want a decodable png, got format=%q err=%v", format, err)
	}
}

func TestUploadJPEGAccepted(t *testing.T) {
	ctx := context.Background()
	svc, store := newTestService(defaultAssetCfg())

	asset, aerr := svc.Upload(ctx, uuid.New(), makeJPEG(t, 320, 240))
	if aerr != nil {
		t.Fatalf("Upload valid JPEG: unexpected error %v", aerr)
	}
	if asset.Width != 320 || asset.Height != 240 {
		t.Fatalf("dimensions: want 320x240, got %dx%d", asset.Width, asset.Height)
	}
	if asset.MimeType != "image/jpeg" {
		t.Fatalf("mime: want image/jpeg, got %s", asset.MimeType)
	}
	if !strings.HasSuffix(asset.StorageRef, ".jpg") {
		t.Fatalf("StorageRef: want a .jpg key, got %q", asset.StorageRef)
	}
	blob := storedBytes(t, store, asset.StorageRef)
	if _, format, err := image.Decode(bytes.NewReader(blob)); err != nil || format != "jpeg" {
		t.Fatalf("stored blob: want a decodable jpeg, got format=%q err=%v", format, err)
	}
}

func TestUploadRejectsNonImage(t *testing.T) {
	svc, _ := newTestService(defaultAssetCfg())
	raw := []byte("this is definitely not an image, just some plain UTF-8 text content")

	_, aerr := svc.Upload(context.Background(), uuid.New(), raw)
	assertValidation(t, aerr, "non-image")
}

func TestUploadRejectsEmpty(t *testing.T) {
	svc, _ := newTestService(defaultAssetCfg())
	_, aerr := svc.Upload(context.Background(), uuid.New(), nil)
	assertValidation(t, aerr, "empty")
}

// A file with a valid PNG magic prefix but a corrupt body passes the sniff and
// must be rejected by the decoder gate, not accepted.
func TestUploadRejectsCorruptWithValidMagic(t *testing.T) {
	svc, _ := newTestService(defaultAssetCfg())
	raw := append([]byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}, []byte("not really a png")...)

	_, aerr := svc.Upload(context.Background(), uuid.New(), raw)
	assertValidation(t, aerr, "corrupt-with-magic")
}

func TestUploadRejectsOversize(t *testing.T) {
	cfg := defaultAssetCfg()
	cfg.MaxBytes = 128 // any real PNG is larger
	svc, _ := newTestService(cfg)

	_, aerr := svc.Upload(context.Background(), uuid.New(), makePNG(t, 256, 256))
	assertValidation(t, aerr, "oversize")
}

func TestUploadRejectsBelowMinDimension(t *testing.T) {
	cfg := defaultAssetCfg()
	cfg.MinDimension = 200
	svc, _ := newTestService(cfg)

	_, aerr := svc.Upload(context.Background(), uuid.New(), makePNG(t, 100, 100))
	assertValidation(t, aerr, "below-min")
}

func TestUploadRejectsAboveMaxDimension(t *testing.T) {
	cfg := defaultAssetCfg()
	cfg.MinDimension = 10
	cfg.MaxDimension = 100
	svc, _ := newTestService(cfg)

	_, aerr := svc.Upload(context.Background(), uuid.New(), makePNG(t, 256, 256))
	assertValidation(t, aerr, "above-max")
}

// TestUploadStripsEXIF is the security-load-bearing test: an uploaded JPEG that
// carries an EXIF (APP1) segment with a GPS/secret canary must be re-encoded so
// the canary is GONE from the stored bytes. This proves re-encoding — not
// byte-passthrough — is what lands on disk (PRD §6.8/§7.8).
func TestUploadStripsEXIF(t *testing.T) {
	ctx := context.Background()
	svc, store := newTestService(defaultAssetCfg())

	canary := []byte("CANARY-GPS-51.5074N-0.1278W-DO-NOT-PERSIST")
	withExif := jpegWithEXIF(t, 256, 256, canary)

	// Sanity: the crafted input really does contain the canary and still sniffs
	// as a JPEG (the splice sits after the SOI marker).
	if !bytes.Contains(withExif, canary) {
		t.Fatal("test setup: crafted JPEG should contain the canary")
	}
	if sniffFormat(withExif) != formatJPEG {
		t.Fatal("test setup: crafted JPEG should still sniff as JPEG")
	}

	asset, aerr := svc.Upload(ctx, uuid.New(), withExif)
	if aerr != nil {
		t.Fatalf("Upload EXIF-bearing JPEG: unexpected error %v", aerr)
	}

	blob := storedBytes(t, store, asset.StorageRef)
	if bytes.Contains(blob, canary) {
		t.Fatal("EXIF canary survived into the stored blob — re-encode did not strip metadata")
	}
	if _, format, err := image.Decode(bytes.NewReader(blob)); err != nil || format != "jpeg" {
		t.Fatalf("stored blob: want a decodable jpeg, got format=%q err=%v", format, err)
	}
}

// jpegWithEXIF encodes a valid JPEG then splices a well-formed APP1 ("Exif")
// segment carrying payload right after the SOI marker. The Go JPEG decoder skips
// APP1 during decode, so the image still decodes; re-encoding drops the segment.
func jpegWithEXIF(t *testing.T, w, h int, payload []byte) []byte {
	t.Helper()
	base := makeJPEG(t, w, h) // starts with SOI: FF D8
	exifBody := append([]byte("Exif\x00\x00"), payload...)
	segLen := len(exifBody) + 2 // length field counts itself, not the FFE1 marker
	if segLen > 0xFFFF {
		t.Fatalf("payload too large for one APP1 segment: %d", segLen)
	}
	app1 := []byte{0xFF, 0xE1, byte(segLen >> 8), byte(segLen & 0xFF)}
	app1 = append(app1, exifBody...)

	out := make([]byte, 0, len(base)+len(app1))
	out = append(out, base[:2]...) // SOI
	out = append(out, app1...)     // injected EXIF
	out = append(out, base[2:]...) // the rest of the original stream
	return out
}

// assertValidation fails unless aerr is a 400 validation_error.
func assertValidation(t *testing.T, aerr *apperror.Error, label string) {
	t.Helper()
	if aerr == nil {
		t.Fatalf("%s: want a validation error, got nil", label)
		return // unreachable after Fatalf, but makes the nil-guard explicit for staticcheck
	}
	if aerr.Code != apperror.CodeValidationError {
		t.Fatalf("%s: want code %q, got %q (%s)", label, apperror.CodeValidationError, aerr.Code, aerr.Message)
	}
	if aerr.HTTPStatus != 400 {
		t.Fatalf("%s: want HTTP 400, got %d", label, aerr.HTTPStatus)
	}
}
