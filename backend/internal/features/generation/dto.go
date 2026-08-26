package generation

import (
	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider"
)

// DTOs mirror openapi.yaml exactly — field names are the JSON contract the
// mobile client is generated against, so renaming one is a breaking change.

// GenerateTextRequest is the body of POST /generate/text.
type GenerateTextRequest struct {
	InputText  string     `json:"input_text" binding:"required"`
	InputLang  string     `json:"input_lang" binding:"required,oneof=en am auto"`
	Platform   string     `json:"platform" binding:"required,oneof=instagram tiktok telegram"`
	BrandKitID *uuid.UUID `json:"brand_kit_id"`
}

// toTextRequest maps the wire request into the provider-agnostic domain shape.
// Brand context (name, tone) is resolved from the brand kit in the handler
// before calling this.
func (r GenerateTextRequest) toTextRequest(brandName, tone string) provider.TextRequest {
	return provider.TextRequest{
		InputText: r.InputText,
		InputLang: r.InputLang,
		Platform:  r.Platform,
		BrandName: brandName,
		Tone:      tone,
	}
}

// GenerateTextResponse is the contract's GenerateTextResponse schema.
type GenerateTextResponse struct {
	CaptionEN    string   `json:"caption_en"`
	CaptionAM    string   `json:"caption_am"`
	CallToAction string   `json:"call_to_action"`
	Hashtags     []string `json:"hashtags"`
}

// textResultToResponse maps the provider result to the wire shape.
func textResultToResponse(r provider.TextResult) GenerateTextResponse {
	return GenerateTextResponse{
		CaptionEN:    r.CaptionEN,
		CaptionAM:    r.CaptionAM,
		CallToAction: r.CallToAction,
		Hashtags:     r.Hashtags,
	}
}

// ── Image generation DTOs ────────────────────────────────────────────────

// GenerateImageRequest is the body of POST /generate/image.
type GenerateImageRequest struct {
	CaptionEN   string     `json:"caption_en" binding:"required"`
	AspectRatio string     `json:"aspect_ratio" binding:"required,oneof=1:1 4:5"` // OQ-02: 9:16 NOT accepted
	BrandKitID  *uuid.UUID `json:"brand_kit_id"`
}

// toImageRequest maps the wire request into the provider-agnostic domain shape.
func (r GenerateImageRequest) toImageRequest(brandName string) provider.ImageRequest {
	return provider.ImageRequest{
		CaptionEN:   r.CaptionEN,
		AspectRatio: r.AspectRatio,
		BrandName:   brandName,
	}
}

// GenerateImageResponse is the contract's GenerateImageResponse schema.
type GenerateImageResponse struct {
	AssetID  uuid.UUID `json:"asset_id"`
	ImageURL string    `json:"image_url"`
	Width    int       `json:"width"`
	Height   int       `json:"height"`
}

// ── Video generation DTOs ────────────────────────────────────────────────

// GenerateVideoRequest is the body of POST /generate/video.
// storyboard_text is the narrative for the video; brand_kit_id is required
// because video always needs brand context (PRD §8.4).
type GenerateVideoRequest struct {
	StoryboardText string     `json:"storyboard_text" binding:"required"`
	BrandKitID     *uuid.UUID `json:"brand_kit_id"`
}

// VideoJobPayload is the opaque JSON stored in queue.Job.Payload. The worker
// decodes this to process the video generation.
type VideoJobPayload struct {
	JobID          uuid.UUID `json:"job_id"`
	UserID         uuid.UUID `json:"user_id"`
	StoryboardText string    `json:"storyboard_text"`
	BrandName      string    `json:"brand_name"`
}

// JobResponse is the contract's Job schema (openapi.yaml).
// FLAG: result_asset_id maps to ResultGenerationRecordID in the PRD model;
// for V1 the video feature maps between them (docs/OPEN_QUESTIONS.md).
type JobResponse struct {
	ID            uuid.UUID  `json:"id"`
	Status        string     `json:"status"`
	ResultAssetID *uuid.UUID `json:"result_asset_id,omitempty"`
}
