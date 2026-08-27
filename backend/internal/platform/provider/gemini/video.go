// Package gemini implements provider.VideoProvider using the Gemini
// Omni Flash model (gemini-omni-1.1-flash) via the /interactions REST endpoint.
// No SDK dependency — just net/http + encoding/json.
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

const videoModelName = "gemini-omni-1.1-flash"

// Video is a Gemini-backed video provider using Omni Flash.
type Video struct {
	apiKey     string
	httpClient *http.Client
}

// NewVideo builds a Gemini video provider.
func NewVideo(apiKey string) *Video {
	return &Video{
		apiKey: apiKey,
		httpClient: &http.Client{
			Timeout: 120 * time.Second, // video generation can be slow
		},
	}
}

// Name identifies this provider in telemetry and the failover chain.
func (*Video) Name() string { return "gemini" }

// Model returns the Gemini model name and version.
func (*Video) Model() (model, version string) { return videoModelName, "v1" }

// ── Gemini interactions API types for video ────────────────────────────────

type videoReq struct {
	Model          string           `json:"model"`
	Input          interface{}      `json:"input"`
	ResponseFormat *videoRespFormat `json:"response_format,omitempty"`
}

type videoRespFormat struct {
	Type        string `json:"type"`
	AspectRatio string `json:"aspect_ratio,omitempty"`
}

type videoResp struct {
	Steps  []videoStep `json:"steps,omitempty"`
	Status string      `json:"status,omitempty"`
	Error  *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

type videoStep struct {
	Type    string             `json:"type"`
	Content []videoStepContent `json:"content,omitempty"`
}

type videoStepContent struct {
	Type     string `json:"type"`
	MimeType string `json:"mime_type,omitempty"`
	Data     string `json:"data,omitempty"`
}

// GenerateVideo calls the Gemini Omni Flash API and returns raw MP4 bytes.
func (v *Video) GenerateVideo(ctx context.Context, req provider.VideoRequest) (provider.VideoResult, error) {
	if err := ctx.Err(); err != nil {
		return provider.VideoResult{}, err
	}

	prompt := videoPrompt(req)

	body, err := json.Marshal(videoReq{
		Model: videoModelName,
		Input: prompt,
		ResponseFormat: &videoRespFormat{
			Type:        "video",
			AspectRatio: req.AspectRatio,
		},
	})
	if err != nil {
		return provider.VideoResult{}, fmt.Errorf("marshal video request: %w", err)
	}

	url := fmt.Sprintf("%s/interactions?key=%s", apiBaseURL, v.apiKey)
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return provider.VideoResult{}, fmt.Errorf("create request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := v.httpClient.Do(httpReq)
	if err != nil {
		return provider.VideoResult{}, fmt.Errorf("video API request failed: %w", err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return provider.VideoResult{}, fmt.Errorf("read video response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return provider.VideoResult{}, fmt.Errorf("video API returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var apiResp videoResp
	if err := json.Unmarshal(respBody, &apiResp); err != nil {
		return provider.VideoResult{}, fmt.Errorf("unmarshal video response: %w", err)
	}

	if apiResp.Error != nil {
		return provider.VideoResult{}, fmt.Errorf("video API error %d: %s", apiResp.Error.Code, apiResp.Error.Message)
	}

	// Extract video bytes from the steps array.
	for _, step := range apiResp.Steps {
		if step.Type == "model_output" {
			for _, c := range step.Content {
				if c.Type == "video" && c.Data != "" {
					return decodeVideoBase64(c.Data)
				}
			}
		}
	}

	return provider.VideoResult{}, fmt.Errorf("%w: no video data in response", provider.ErrMalformedOutput)
}

// videoPrompt builds the user prompt for video generation.
func videoPrompt(req provider.VideoRequest) string {
	prompt := req.StoryboardText
	if req.BrandName != "" {
		prompt += fmt.Sprintf(" Brand: %s.", req.BrandName)
	}
	prompt += " Create a short, engaging social media video."
	return prompt
}

// decodeVideoBase64 decodes a base64-encoded MP4 video.
func decodeVideoBase64(data string) (provider.VideoResult, error) {
	decoded, err := base64.StdEncoding.DecodeString(data)
	if err != nil {
		return provider.VideoResult{}, fmt.Errorf("%w: base64 decode failed: %v", provider.ErrMalformedOutput, err)
	}

	return provider.VideoResult{
		VideoBytes: decoded,
		MimeType:   "video/mp4",
		Width:      720,
		Height:     1280,
	}, nil
}
