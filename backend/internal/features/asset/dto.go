package asset

import (
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// assetResponse is the contract's Asset schema (api/openapi.yaml) — the fields
// returned after a successful upload. It deliberately omits owner_user_id and
// storage_ref: the owner is never disclosed, and the storage location is an
// internal detail (bytes are served later via a separate, access-checked route,
// never by raw path).
type assetResponse struct {
	ID        uuid.UUID `json:"id"`
	Width     int       `json:"width"`
	Height    int       `json:"height"`
	MimeType  string    `json:"mime_type"`
	CreatedAt time.Time `json:"created_at"`
}

// toResponse maps a stored asset to the wire shape.
func toResponse(a *models.Asset) assetResponse {
	return assetResponse{
		ID:        a.ID,
		Width:     a.Width,
		Height:    a.Height,
		MimeType:  a.MimeType,
		CreatedAt: a.CreatedAt,
	}
}
