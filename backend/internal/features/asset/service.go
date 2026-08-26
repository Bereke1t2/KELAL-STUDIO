package asset

import (
	"bytes"
	"context"
	"fmt"
	"image"
	"image/jpeg"
	"image/png"
	"log/slog"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/storage"
)

// reencodeJPEGQuality is the quality for re-encoded JPEGs. 85 is the usual
// visually-lossless / reasonable-size tradeoff; the exact value isn't a contract.
const reencodeJPEGQuality = 85

// The only accepted formats. These strings are exactly what image.DecodeConfig /
// image.Decode report for the stdlib decoders registered by the image/jpeg and
// image/png imports above — importing any other decoder would widen the allowlist,
// so the import list is itself part of the security posture.
const (
	formatJPEG = "jpeg"
	formatPNG  = "png"
)

// Magic-byte signatures used to sniff the type from content before we trust any
// decoder. JPEG starts FF D8 FF; PNG has an 8-byte signature.
var (
	sigJPEG = []byte{0xFF, 0xD8, 0xFF}
	sigPNG  = []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}
)

// Service holds the asset use cases. Upload is the one use case and returns
// (result, *apperror.Error) — failures are values the delivery layer renders,
// never panics. The service depends only on the Repository port (row storage),
// the Store port (blob storage), and the stdlib image codecs.
type Service struct {
	repo  Repository
	store storage.Store
	cfg   config.AssetConfig
	log   *slog.Logger
}

// NewService wires the use case.
func NewService(repo Repository, store storage.Store, cfg config.AssetConfig, log *slog.Logger) *Service {
	return &Service{repo: repo, store: store, cfg: cfg, log: log}
}

// Upload hardens raw uploaded bytes and persists the result (PRD §6.8, §7.8).
// The step ORDER is security-load-bearing — cheap content/size/dimension checks
// gate the expensive full decode, which gates the re-encode that actually strips
// metadata and neutralizes polyglots. Every rejection is a validation_error (400)
// with a message that says what to fix, never why internally (no oracle).
//
// The policy choices baked in here — JPEG/PNG only, REJECT (not downscale)
// out-of-range dimensions, re-encode preserving the format family, and 400 for
// every rejection rather than 413/415 — are flagged as `asset-upload-policy` in
// docs/OPEN_QUESTIONS.md, not silently resolved.
func (s *Service) Upload(ctx context.Context, ownerID uuid.UUID, raw []byte) (*models.Asset, *apperror.Error) {
	// 1. Size bound (defense in depth; the handler also caps the request stream).
	if len(raw) == 0 {
		return nil, apperror.Validation("the uploaded file is empty")
	}
	if int64(len(raw)) > s.cfg.MaxBytes {
		return nil, apperror.Validation("the image exceeds the maximum allowed size")
	}

	// 2. Content sniff by magic bytes — the ONLY thing we trust for the type.
	format := sniffFormat(raw)
	if format == "" {
		return nil, apperror.Validation("unsupported image type; upload a JPEG or PNG")
	}

	// 3. Header-only dimension read BEFORE decoding pixels, so a decompression
	// bomb is rejected on its declared dimensions rather than by allocating the
	// full bitmap. DecodeConfig also reports the format, a second gate on the
	// allowlist (only jpeg/png decoders are registered).
	hdr, hdrFormat, err := image.DecodeConfig(bytes.NewReader(raw))
	if err != nil || hdrFormat != format {
		return nil, apperror.Validation("unsupported or corrupt image")
	}
	if hdr.Width < s.cfg.MinDimension || hdr.Height < s.cfg.MinDimension {
		return nil, apperror.Validation(fmt.Sprintf("the image is smaller than the %dpx minimum on a side", s.cfg.MinDimension))
	}
	if hdr.Width > s.cfg.MaxDimension || hdr.Height > s.cfg.MaxDimension {
		return nil, apperror.Validation(fmt.Sprintf("the image is larger than the %dpx maximum on a side", s.cfg.MaxDimension))
	}

	// 4. Full decode → pixels only. Any EXIF/GPS/ICC/appended data is dropped
	// here; only the decoded raster survives into img.
	img, decFormat, err := image.Decode(bytes.NewReader(raw))
	if err != nil || decFormat != format {
		return nil, apperror.Validation("the image could not be read")
	}

	// 5. Re-encode from the decoded pixels into fresh bytes. This is what
	// guarantees no original metadata or trailing payload survives, and it
	// canonicalizes the stored artifact.
	out, mimeType, ext, aerr := reencode(img, format)
	if aerr != nil {
		s.log.Error("asset re-encode failed", "error", aerr.Error())
		return nil, aerr
	}

	// 6. Persist the bytes under a sharded key, OUTSIDE any web root.
	id := uuid.New()
	key := storageKey(id, ext)
	if err := s.store.Put(ctx, key, out); err != nil {
		s.log.Error("asset blob write failed", "asset_id", id.String(), "error", err.Error())
		return nil, apperror.Internal(err)
	}

	// 7. Record the row. On failure, best-effort remove the orphaned blob so a
	// DB error doesn't leak bytes onto disk with no row pointing at them.
	b := img.Bounds()
	asset := &models.Asset{
		Base:             models.Base{ID: id},
		OwnerUserID:      ownerID,
		StorageRef:       key,
		Width:            b.Dx(),
		Height:           b.Dy(),
		MimeType:         mimeType,
		StrippedMetadata: true,
		CreatedAt:        time.Now().UTC(),
	}
	if err := s.repo.Create(ctx, asset); err != nil {
		if derr := s.store.Delete(ctx, key); derr != nil {
			s.log.Error("failed to remove orphaned asset blob", "asset_id", id.String(), "key", key, "error", derr.Error())
		}
		s.log.Error("asset row insert failed", "asset_id", id.String(), "error", err.Error())
		return nil, apperror.Internal(err)
	}
	return asset, nil
}

// sniffFormat identifies the image type from its leading magic bytes — never the
// filename or the client-sent Content-Type, both attacker-controlled (PRD §6.8).
// It returns formatJPEG / formatPNG, or "" for anything else.
func sniffFormat(b []byte) string {
	switch {
	case bytes.HasPrefix(b, sigJPEG):
		return formatJPEG
	case bytes.HasPrefix(b, sigPNG):
		return formatPNG
	default:
		return ""
	}
}

// reencode writes the decoded image back out in its own format family, stripping
// all metadata in the process. PNG stays PNG (lossless, may carry alpha); JPEG
// stays JPEG at a fixed quality. It returns the bytes, the canonical MIME type,
// and the file extension used in the storage key.
func reencode(img image.Image, format string) ([]byte, string, string, *apperror.Error) {
	var buf bytes.Buffer
	switch format {
	case formatPNG:
		if err := png.Encode(&buf, img); err != nil {
			return nil, "", "", apperror.Internal(err)
		}
		return buf.Bytes(), "image/png", "png", nil
	case formatJPEG:
		if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: reencodeJPEGQuality}); err != nil {
			return nil, "", "", apperror.Internal(err)
		}
		return buf.Bytes(), "image/jpeg", "jpg", nil
	default:
		// Unreachable: format is validated by sniffFormat before we get here.
		return nil, "", "", apperror.Internal(fmt.Errorf("asset: unexpected format %q", format))
	}
}

// storageKey derives the blob key for an asset: sharded by the first two hex
// characters of its id so no single directory holds millions of entries, e.g.
// "3f/3f7c9b1e-....png". The id is a random uuid, so the shard spreads evenly.
func storageKey(id uuid.UUID, ext string) string {
	h := id.String()
	return h[0:2] + "/" + h + "." + ext
}
