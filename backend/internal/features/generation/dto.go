package generation

import (
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider"
)

// DTOs mirror openapi.yaml exactly — field names are the JSON contract the
// mobile client is generated against, so renaming one is a breaking change.

// generateTextRequest is the body of POST /generate/text.
type generateTextRequest struct {
	InputText  string     `json:"input_text" binding:"required"`
	InputLang  string     `json:"input_lang" binding:"required,oneof=en am auto"`
	Platform   string     `json:"platform" binding:"required,oneof=instagram tiktok telegram"`
	BrandKitID *uuid.UUID `json:"brand_kit_id"`
}

// toTextRequest maps the wire request into the provider-agnostic domain shape.
// Brand context (name, tone) is resolved from the brand kit in the handler
// before calling this.
func (r generateTextRequest) toTextRequest(brandName, tone string) provider.TextRequest {
	return provider.TextRequest{
		InputText: r.InputText,
		InputLang: r.InputLang,
		Platform:  r.Platform,
		BrandName: brandName,
		Tone:      tone,
	}
}

// generateTextResponse is the contract's GenerateTextResponse schema.
type generateTextResponse struct {
	CaptionEN    string   `json:"caption_en"`
	CaptionAM    string   `json:"caption_am"`
	CallToAction string   `json:"call_to_action"`
	Hashtags     []string `json:"hashtags"`
}

// textResultToResponse maps the provider result to the wire shape.
func textResultToResponse(r provider.TextResult) generateTextResponse {
	return generateTextResponse{
		CaptionEN:    r.CaptionEN,
		CaptionAM:    r.CaptionAM,
		CallToAction: r.CallToAction,
		Hashtags:     r.Hashtags,
	}
}

// ── Image generation DTOs ────────────────────────────────────────────────

// generateImageRequest is the body of POST /generate/image.
type generateImageRequest struct {
	CaptionEN   string     `json:"caption_en" binding:"required"`
	AspectRatio string     `json:"aspect_ratio" binding:"required,oneof=1:1 4:5"` // OQ-02: 9:16 NOT accepted
	BrandKitID  *uuid.UUID `json:"brand_kit_id"`
}

// toImageRequest maps the wire request into the provider-agnostic domain shape.
func (r generateImageRequest) toImageRequest(brandName string) provider.ImageRequest {
	return provider.ImageRequest{
		CaptionEN:   r.CaptionEN,
		AspectRatio: r.AspectRatio,
		BrandName:   brandName,
	}
}

// generateImageResponse is the contract's GenerateImageResponse schema.
type generateImageResponse struct {
	AssetID  uuid.UUID `json:"asset_id"`
	ImageURL string    `json:"image_url"`
	Width    int       `json:"width"`
	Height   int       `json:"height"`
}

// ── Video generation DTOs ────────────────────────────────────────────────

// generateVideoRequest is the body of POST /generate/video.
// storyboard_text is the narrative for the video; brand_kit_id is required
// because video always needs brand context (PRD §8.4).
type generateVideoRequest struct {
	StoryboardText string     `json:"storyboard_text" binding:"required"`
	BrandKitID     *uuid.UUID `json:"brand_kit_id"`
}

// videoJobPayload is the opaque JSON stored in queue.Job.Payload. The worker
// decodes this to process the video generation.
type videoJobPayload struct {
	JobID          uuid.UUID `json:"job_id"`
	UserID         uuid.UUID `json:"user_id"`
	StoryboardText string    `json:"storyboard_text"`
	BrandName      string    `json:"brand_name"`
}

// jobResponse is the contract's Job schema (openapi.yaml).
// FLAG: result_asset_id maps to ResultGenerationRecordID in the PRD model;
// for V1 the video feature maps between them (docs/OPEN_QUESTIONS.md).
type jobResponse struct {
	ID            uuid.UUID  `json:"id"`
	Status        string     `json:"status"`
	ResultAssetID *uuid.UUID `json:"result_asset_id,omitempty"`
}

// brandKitResponse is a minimal projection of a BrandKit used for context.
// The generation feature does NOT expose full brand kit CRUD — it only reads
// brand context for the provider.
type brandKitResponse struct {
	ID              uuid.UUID `json:"id"`
	BrandName       string    `json:"brand_name"`
	PrimaryColorHex string    `json:"primary_color_hex"`
	ToneOfVoice     string    `json:"tone_of_voice"`
	UpdatedAt       time.Time `json:"updated_at"`
}

// brandKitToResponse maps a stored BrandKit model to a minimal projection.
func brandKitToResponse(k *models.BrandKit) brandKitResponse {
	return brandKitResponse{
		ID:              k.ID,
		BrandName:       k.BrandName,
		PrimaryColorHex: k.PrimaryColorHex,
		ToneOfVoice:     k.ToneOfVoice,
		UpdatedAt:       k.UpdatedAt,
	}
}
