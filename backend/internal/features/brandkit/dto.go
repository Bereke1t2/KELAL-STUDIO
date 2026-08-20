package brandkit

import (
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// DTOs mirror the BrandKit schema in api/openapi.yaml exactly — field names are
// the JSON contract the mobile client is generated against, so renaming one is a
// breaking change.

// brandKitRequest is the body of PUT /brand-kits/{id}. The contract's request
// schema is the full BrandKit, but the server-owned fields (id, updated_at) are
// intentionally NOT bound here: id comes from the path and updated_at is set by
// the server. Any such fields in the body are simply ignored.
//
// logo_asset_id is typed as *uuid.UUID so binding rejects a malformed value
// (400) while allowing null/omitted (a kit may have no logo yet, PRD §6.8).
// Colors and free-text fields are unconstrained strings, matching the contract
// and the unbounded `text` columns in the schema — the backend does not tighten
// beyond what the client is generated to send.
type brandKitRequest struct {
	BrandName         string     `json:"brand_name"`
	LogoAssetID       *uuid.UUID `json:"logo_asset_id"`
	PrimaryColorHex   string     `json:"primary_color_hex"`
	SecondaryColorHex string     `json:"secondary_color_hex"`
	ToneOfVoice       string     `json:"tone_of_voice"`
	ContactInfo       string     `json:"contact_info"`
}

// toInput maps the wire request into the service's domain Input. The two share
// an identical field shape by design (the mutable brand-kit fields), so this is
// a direct conversion — if they ever diverge, this stops compiling, which is the
// intended forcing function to reconcile them.
func (r brandKitRequest) toInput() Input {
	return Input(r)
}

// brandKitResponse is the contract's BrandKit schema — returned by GET and PUT.
// It deliberately omits user_id and created_at: the owner is never disclosed and
// the contract carries only updated_at.
type brandKitResponse struct {
	ID                uuid.UUID  `json:"id"`
	BrandName         string     `json:"brand_name"`
	LogoAssetID       *uuid.UUID `json:"logo_asset_id"`
	PrimaryColorHex   string     `json:"primary_color_hex"`
	SecondaryColorHex string     `json:"secondary_color_hex"`
	ToneOfVoice       string     `json:"tone_of_voice"`
	ContactInfo       string     `json:"contact_info"`
	UpdatedAt         time.Time  `json:"updated_at"`
}

// toResponse maps a stored model to the wire shape.
func toResponse(k *models.BrandKit) brandKitResponse {
	return brandKitResponse{
		ID:                k.ID,
		BrandName:         k.BrandName,
		LogoAssetID:       k.LogoAssetID,
		PrimaryColorHex:   k.PrimaryColorHex,
		SecondaryColorHex: k.SecondaryColorHex,
		ToneOfVoice:       k.ToneOfVoice,
		ContactInfo:       k.ContactInfo,
		UpdatedAt:         k.UpdatedAt,
	}
}
