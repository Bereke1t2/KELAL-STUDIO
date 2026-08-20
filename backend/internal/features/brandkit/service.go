package brandkit

import (
	"context"
	"errors"
	"log/slog"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
)

// Service holds the brand-kit use cases. Each public method is ONE use case and
// returns (result, *apperror.Error) — failures are values the delivery layer
// renders, never panics. The service depends only on the Repository port, never
// on GORM or gin.
type Service struct {
	repo Repository
	log  *slog.Logger
}

// NewService wires the use cases.
func NewService(repo Repository, log *slog.Logger) *Service {
	return &Service{repo: repo, log: log}
}

// Get returns the caller's brand kit.
//
// Ownership is enforced here, and a kit owned by someone else is reported as
// NotFound — the SAME response as a kit that does not exist. Returning 403
// instead would confirm the id belongs to another account, letting a caller
// enumerate valid kit ids; the 404 leaks nothing (mirrors the auth feature's
// anti-enumeration stance, PRD §6.1/§6.8).
func (s *Service) Get(ctx context.Context, id, ownerID uuid.UUID) (*models.BrandKit, *apperror.Error) {
	kit, err := s.repo.FindByID(ctx, id)
	if err != nil {
		if errors.Is(err, ErrBrandKitNotFound) {
			return nil, notFound()
		}
		return nil, apperror.Internal(err)
	}
	if kit.UserID != ownerID {
		return nil, notFound()
	}
	return kit, nil
}

// Upsert applies input to the caller's brand kit, creating it if absent.
//
// FLAG (open question, see docs/OPEN_QUESTIONS.md → brandkit-creation): the HTTP
// contract exposes only GET and PUT /brand-kits/{id} — there is NO create
// endpoint. So a strictly update-only PUT would make a kit uncreatable through
// the documented API. V1 therefore treats PUT as an idempotent, owner-scoped
// upsert: update the caller's kit, or create one at the given id owned by the
// caller if none exists. This is not silently resolved — it's flagged in the
// spec and closes when product confirms the creation flow. Do not "fix" it by
// picking a side in a PR.
//
// Writing over a kit owned by another user is refused as NotFound, for the same
// non-enumeration reason as Get.
func (s *Service) Upsert(ctx context.Context, id, ownerID uuid.UUID, in Input) (*models.BrandKit, *apperror.Error) {
	existing, err := s.repo.FindByID(ctx, id)
	switch {
	case err == nil:
		// A kit exists at this id. Only its owner may overwrite it.
		if existing.UserID != ownerID {
			return nil, notFound()
		}
		apply(existing, in)
		if err := s.repo.Update(ctx, existing); err != nil {
			if errors.Is(err, ErrBrandKitNotFound) {
				// Raced with a delete; brand kits aren't deletable today, so this
				// is effectively unreachable, but stay honest rather than 500.
				return nil, notFound()
			}
			return nil, apperror.Internal(err)
		}
		return existing, nil

	case errors.Is(err, ErrBrandKitNotFound):
		// No kit at this id yet: create one owned by the caller, honoring the
		// client-supplied id (proper PUT semantics — "make the resource at this
		// URI be this"). See the brandkit-creation FLAG above.
		kit := &models.BrandKit{
			Base:   models.Base{ID: id},
			UserID: ownerID,
		}
		apply(kit, in)
		if err := s.repo.Create(ctx, kit); err != nil {
			if errors.Is(err, ErrBrandKitExists) {
				// Lost a create race for this id (astronomically unlikely with a
				// random uuid). Surface a conflict rather than clobbering.
				return nil, apperror.Conflict("that brand kit id is already in use")
			}
			return nil, apperror.Internal(err)
		}
		return kit, nil

	default:
		return nil, apperror.Internal(err)
	}
}

// apply copies the mutable input fields onto a kit. It never touches id,
// user_id, or timestamps — those are server-owned. logo_asset_id is stored as
// an opaque reference; its existence is NOT validated here: the asset feature
// isn't built yet, features never import each other, and referential integrity
// of this column is part of the deferred foreign-key open item
// (docs/OPEN_QUESTIONS.md → foreign-key constraints).
func apply(kit *models.BrandKit, in Input) {
	kit.BrandName = in.BrandName
	kit.LogoAssetID = in.LogoAssetID
	kit.PrimaryColorHex = in.PrimaryColorHex
	kit.SecondaryColorHex = in.SecondaryColorHex
	kit.ToneOfVoice = in.ToneOfVoice
	kit.ContactInfo = in.ContactInfo
}

// notFound is the single response for "no such kit" and "not your kit" — same
// code, status, and message, so the two are indistinguishable to a caller.
func notFound() *apperror.Error {
	return apperror.NotFound("brand kit not found")
}
