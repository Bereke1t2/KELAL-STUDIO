// Package gemini implements provider.TextProvider using the Google Generative
// AI (Gemini) REST API. No SDK dependency — just net/http + encoding/json.
//
// The prompt instructs Gemini to return a structured JSON payload matching
// provider.TextResult, so the caller gets bilingual captions + hashtags.
package gemini

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/provider"
)

const (
	name       = "gemini"
	modelName  = "gemini-3.6-flash"
	apiBaseURL = "https://generativelanguage.googleapis.com/v1beta"
)

// Text is a Gemini-backed text provider.
type Text struct {
	apiKey     string
	httpClient *http.Client
}

// NewText builds a Gemini text provider.
func NewText(apiKey string) *Text {
	return &Text{
		apiKey: apiKey,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// Name identifies this provider in telemetry and the failover chain.
func (*Text) Name() string { return name }

// Model returns the Gemini model name and version.
func (*Text) Model() (model, version string) { return modelName, "v1" }

// ── Gemini API request/response types ──────────────────────────────────────

type geminiRequest struct {
	Contents          []geminiContent  `json:"contents"`
	GenerationConfig  *geminiGenConfig `json:"generationConfig,omitempty"`
	SystemInstruction *geminiContent   `json:"systemInstruction,omitempty"`
}

type geminiContent struct {
	Parts []geminiPart `json:"parts"`
}

type geminiPart struct {
	Text string `json:"text"`
}

type geminiGenConfig struct {
	ResponseMimeType string   `json:"responseMimeType,omitempty"`
	ResponseSchema   any      `json:"responseSchema,omitempty"`
	Temperature      *float64 `json:"temperature,omitempty"`
	MaxOutputTokens  *int     `json:"maxOutputTokens,omitempty"`
}

type geminiResponse struct {
	Candidates []struct {
		Content struct {
			Parts []struct {
				Text string `json:"text"`
			} `json:"parts"`
		} `json:"content"`
	} `json:"candidates"`
	Error *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

// ── Structured output types for the model ──────────────────────────────────

// captionOutput is the schema we ask Gemini to produce.
type captionOutput struct {
	CaptionEN    string   `json:"caption_en"`
	CaptionAM    string   `json:"caption_am"`
	CallToAction string   `json:"call_to_action"`
	Hashtags     []string `json:"hashtags"`
}

// systemPrompt is the system instruction that shapes the model's behavior.
const systemPrompt = `You are Kelal Studio's AI caption writer for Ethiopian small businesses.

Rules:
1. Write captions in English (caption_en) AND Amharic (caption_am).
2. The Amharic must be a natural translation, not transliteration.
3. Keep captions concise and engaging (1–3 sentences).
4. Write a short call-to-action (2–5 words).
5. Generate 5–8 relevant hashtags. Start with #kelal.
6. Adapt tone to the platform:
   - Instagram: visual, emoji-friendly, lifestyle
   - TikTok: punchy, trend-aware, casual
   - Telegram: informative, professional
7. If a brand name is provided, weave it naturally into the caption.
8. If a tone is provided (e.g. "professional", "playful", "luxury"), match it.
9. If the input language is Amharic, also produce the Amharic version as the primary.

Respond ONLY with valid JSON matching this schema:
{
  "caption_en": "string",
  "caption_am": "string",
  "call_to_action": "string",
  "hashtags": ["string"]
}`

// GenerateText calls the Gemini API and parses the structured output.
func (t *Text) GenerateText(ctx context.Context, req provider.TextRequest) (provider.TextResult, error) {
	if err := ctx.Err(); err != nil {
		return provider.TextResult{}, err
	}

	// Build the user message.
	userMsg := buildUserMessage(req)

	// Build the Gemini request with JSON response format.
	temp := 0.7
	maxTokens := 1024
	geminiReq := geminiRequest{
		Contents: []geminiContent{
			{Parts: []geminiPart{{Text: userMsg}}},
		},
		SystemInstruction: &geminiContent{
			Parts: []geminiPart{{Text: systemPrompt}},
		},
		GenerationConfig: &geminiGenConfig{
			ResponseMimeType: "application/json",
			Temperature:      &temp,
			MaxOutputTokens:  &maxTokens,
		},
	}

	body, err := json.Marshal(geminiReq)
	if err != nil {
		return provider.TextResult{}, fmt.Errorf("marshal gemini request: %w", err)
	}

	// Call the Gemini API.
	url := fmt.Sprintf("%s/models/%s:generateContent?key=%s", apiBaseURL, modelName, t.apiKey)
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return provider.TextResult{}, fmt.Errorf("create request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := t.httpClient.Do(httpReq)
	if err != nil {
		return provider.TextResult{}, fmt.Errorf("gemini API request failed: %w", err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return provider.TextResult{}, fmt.Errorf("read gemini response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return provider.TextResult{}, fmt.Errorf("gemini API returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var geminiResp geminiResponse
	if err := json.Unmarshal(respBody, &geminiResp); err != nil {
		return provider.TextResult{}, fmt.Errorf("unmarshal gemini response: %w", err)
	}

	if geminiResp.Error != nil {
		return provider.TextResult{}, fmt.Errorf("gemini API error %d: %s", geminiResp.Error.Code, geminiResp.Error.Message)
	}

	if len(geminiResp.Candidates) == 0 || len(geminiResp.Candidates[0].Content.Parts) == 0 {
		return provider.TextResult{}, provider.ErrMalformedOutput
	}

	// Extract the JSON text from the response.
	rawText := geminiResp.Candidates[0].Content.Parts[0].Text
	rawText = strings.TrimSpace(rawText)

	// Parse the structured output.
	var output captionOutput
	if err := json.Unmarshal([]byte(rawText), &output); err != nil {
		return provider.TextResult{}, fmt.Errorf("%w: %s", provider.ErrMalformedOutput, err.Error())
	}

	// Validate required fields.
	if output.CaptionEN == "" && output.CaptionAM == "" {
		return provider.TextResult{}, provider.ErrMalformedOutput
	}

	// Ensure we have at least some hashtags.
	if len(output.Hashtags) == 0 {
		output.Hashtags = []string{"#kelal", "#ethiopia"}
	}

	// Ensure caption_am is not empty — fallback to caption_en if model missed it.
	if output.CaptionAM == "" {
		output.CaptionAM = output.CaptionEN
	}

	return provider.TextResult{
		CaptionEN:    output.CaptionEN,
		CaptionAM:    output.CaptionAM,
		CallToAction: output.CallToAction,
		Hashtags:     output.Hashtags,
	}, nil
}

// buildUserMessage constructs the user prompt from the request fields.
func buildUserMessage(req provider.TextRequest) string {
	var b strings.Builder

	b.WriteString(fmt.Sprintf("Write a social media caption for: %s\n", req.InputText))

	if req.Platform != "" {
		b.WriteString(fmt.Sprintf("Platform: %s\n", req.Platform))
	}
	if req.BrandName != "" {
		b.WriteString(fmt.Sprintf("Brand: %s\n", req.BrandName))
	}
	if req.Tone != "" {
		b.WriteString(fmt.Sprintf("Tone: %s\n", req.Tone))
	}
	if req.InputLang != "" && req.InputLang != "auto" {
		b.WriteString(fmt.Sprintf("Input language: %s\n", req.InputLang))
	}

	return b.String()
}
