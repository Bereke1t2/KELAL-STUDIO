// Package gemini implements provider.ImageProvider using the Gemini
// Nano Banana Lite model (gemini-3.1-flash-lite-image) via the
// /interactions REST endpoint. No SDK dependency — just net/http + encoding/json.
package gemini

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider"
)

const (
	imageModelName  = "gemini-2.5-flash-image"
	interactionsURL = apiBaseURL + "/interactions"
)

// Image is a Gemini-backed image provider using Nano Banana Lite.
type Image struct {
	apiKey     string
	httpClient *http.Client
}

// NewImage builds a Gemini image provider.
func NewImage(apiKey string) *Image {
	return &Image{
		apiKey: apiKey,
		httpClient: &http.Client{
			Timeout: 60 * time.Second, // image generation can be slow
		},
	}
}

// Name identifies this provider in telemetry and the failover chain.
func (*Image) Name() string { return "gemini" }

// Model returns the Gemini model name and version.
func (*Image) Model() (model, version string) { return imageModelName, "v1" }

// ── Gemini interactions API request/response types ─────────────────────────

type interactionsRequest struct {
	Model string         `json:"model"`
	Input []inputContent `json:"input"`
}

type inputContent struct {
	Type string `json:"type"`
	Text string `json:"text,omitempty"`
}

type interactionsResponse struct {
	Interaction *interactionData `json:"interaction,omitempty"`
	Error       *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

type interactionData struct {
	OutputImage *outputImageData `json:"output_image,omitempty"`
}

type outputImageData struct {
	Data string `json:"data"` // base64-encoded image bytes
}

// ── Gemini generateContent fallback types ──────────────────────────────────

type gcRequest struct {
	Contents         []gcContent `json:"contents"`
	GenerationConfig *gcConfig   `json:"generationConfig,omitempty"`
}

type gcContent struct {
	Parts []gcPart `json:"parts"`
}

type gcPart struct {
	Text string `json:"text,omitempty"`
}

type gcConfig struct {
	ResponseModalities []string `json:"responseModalities"`
}

type gcResponse struct {
	Candidates []struct {
		Content struct {
			Parts []gcRespPart `json:"parts"`
		} `json:"content"`
	} `json:"candidates"`
	Error *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

type gcRespPart struct {
	InlineData *gcInlineData `json:"inlineData,omitempty"`
}

type gcInlineData struct {
	MimeType string `json:"mimeType"`
	Data     string `json:"data"` // base64-encoded
}

// imagePrompt builds the user prompt for image generation.
func imagePrompt(req provider.ImageRequest) string {
	prompt := fmt.Sprintf("Generate an image for a social media post. Caption: %s", req.CaptionEN)
	if req.BrandName != "" {
		prompt += fmt.Sprintf(" Brand: %s", req.BrandName)
	}
	if req.AspectRatio == "4:5" {
		prompt += " Aspect ratio: portrait 4:5, suitable for Instagram feed."
	} else {
		prompt += " Aspect ratio: square 1:1, suitable for Instagram feed."
	}
	prompt += " High quality, professional, visually appealing."
	return prompt
}

// GenerateImage calls the Gemini Nano Banana Lite API and returns raw image bytes.
func (img *Image) GenerateImage(ctx context.Context, req provider.ImageRequest) (provider.ImageResult, error) {
	if err := ctx.Err(); err != nil {
		return provider.ImageResult{}, err
	}

	// Try the interactions API first (Nano Banana Lite native endpoint).
	result, err := img.tryInteractions(ctx, req)
	if err == nil {
		return result, nil
	}
	// Fallback to generateContent with responseModalities (older Gemini models).
	return img.tryGenerateContent(ctx, req)
}

func (img *Image) tryInteractions(ctx context.Context, req provider.ImageRequest) (provider.ImageResult, error) {
	prompt := imagePrompt(req)

	body, err := json.Marshal(interactionsRequest{
		Model: imageModelName,
		Input: []inputContent{
			{Type: "text", Text: prompt},
		},
	})
	if err != nil {
		return provider.ImageResult{}, fmt.Errorf("marshal interactions request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, interactionsURL, bytes.NewReader(body))
	if err != nil {
		return provider.ImageResult{}, fmt.Errorf("create request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("x-goog-api-key", img.apiKey)

	resp, err := img.httpClient.Do(httpReq)
	if err != nil {
		return provider.ImageResult{}, fmt.Errorf("interactions API request failed: %w", err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return provider.ImageResult{}, fmt.Errorf("read interactions response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return provider.ImageResult{}, fmt.Errorf("interactions API returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var apiResp interactionsResponse
	if err := json.Unmarshal(respBody, &apiResp); err != nil {
		return provider.ImageResult{}, fmt.Errorf("unmarshal interactions response: %w", err)
	}

	if apiResp.Error != nil {
		return provider.ImageResult{}, fmt.Errorf("interactions API error %d: %s", apiResp.Error.Code, apiResp.Error.Message)
	}

	if apiResp.Interaction == nil || apiResp.Interaction.OutputImage == nil || apiResp.Interaction.OutputImage.Data == "" {
		return provider.ImageResult{}, fmt.Errorf("%w: no output_image in interactions response", provider.ErrMalformedOutput)
	}

	return decodeImageBase64(apiResp.Interaction.OutputImage.Data)
}

func (img *Image) tryGenerateContent(ctx context.Context, req provider.ImageRequest) (provider.ImageResult, error) {
	prompt := imagePrompt(req)

	body, err := json.Marshal(gcRequest{
		Contents: []gcContent{
			{Parts: []gcPart{{Text: prompt}}},
		},
		GenerationConfig: &gcConfig{
			ResponseModalities: []string{"image", "text"},
		},
	})
	if err != nil {
		return provider.ImageResult{}, fmt.Errorf("marshal generateContent request: %w", err)
	}

	url := fmt.Sprintf("%s/models/%s:generateContent?key=%s", apiBaseURL, imageModelName, img.apiKey)
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return provider.ImageResult{}, fmt.Errorf("create request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := img.httpClient.Do(httpReq)
	if err != nil {
		return provider.ImageResult{}, fmt.Errorf("generateContent API request failed: %w", err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return provider.ImageResult{}, fmt.Errorf("read generateContent response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return provider.ImageResult{}, fmt.Errorf("generateContent API returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var apiResp gcResponse
	if err := json.Unmarshal(respBody, &apiResp); err != nil {
		return provider.ImageResult{}, fmt.Errorf("unmarshal generateContent response: %w", err)
	}

	if apiResp.Error != nil {
		return provider.ImageResult{}, fmt.Errorf("generateContent API error %d: %s", apiResp.Error.Code, apiResp.Error.Message)
	}

	if len(apiResp.Candidates) == 0 {
		return provider.ImageResult{}, fmt.Errorf("%w: no candidates in generateContent response", provider.ErrMalformedOutput)
	}

	// Find the part with inline data (the image).
	for _, p := range apiResp.Candidates[0].Content.Parts {
		if p.InlineData != nil && p.InlineData.Data != "" {
			return decodeImageBase64(p.InlineData.Data)
		}
	}

	return provider.ImageResult{}, fmt.Errorf("%w: no image data in generateContent response", provider.ErrMalformedOutput)
}

// decodeImageBase64 decodes a base64-encoded image and detects MIME type.
func decodeImageBase64(data string) (provider.ImageResult, error) {
	decoded, err := base64.StdEncoding.DecodeString(data)
	if err != nil {
		return provider.ImageResult{}, fmt.Errorf("%w: base64 decode failed: %v", provider.ErrMalformedOutput, err)
	}

	// Detect MIME type from magic bytes.
	mimeType := "image/png"
	if len(decoded) >= 3 && decoded[0] == 0xFF && decoded[1] == 0xD8 && decoded[2] == 0xFF {
		mimeType = "image/jpeg"
	}

	return provider.ImageResult{
		ImageBytes: decoded,
		MimeType:   mimeType,
		Width:      1024,
		Height:     1024,
	}, nil
}
