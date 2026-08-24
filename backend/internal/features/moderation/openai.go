package moderation

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// openaiChecker implements Checker using the OpenAI Moderation API
// (https://platform.openai.com/docs/guides/moderation). The API is free and
// returns structured safety categories with scores.
type openaiChecker struct {
	apiKey     string
	httpClient *http.Client
}

// NewOpenAIChecker builds a moderation checker backed by the OpenAI Moderation
// endpoint. The apiKey is the OPENAI_API_KEY.
func NewOpenAIChecker(apiKey string) Checker {
	return &openaiChecker{
		apiKey: apiKey,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// moderationRequest is the OpenAI Moderation API request body.
type moderationRequest struct {
	Input string `json:"input"`
}

// moderationResponse is the OpenAI Moderation API response body.
type moderationResponse struct {
	ID      string `json:"id"`
	Results []struct {
		Flagged        bool              `json:"flagged"`
		Categories     map[string]bool   `json:"categories"`
		CategoryScores map[string]float64 `json:"category_scores"`
	} `json:"results"`
}

// humanReadable maps OpenAI category names to plain-language reasons.
var humanReadable = map[string]string{
	"sexual":            "Content contains sexual material",
	"hate":              "Content contains hate speech",
	"harassment":        "Content contains harassment",
	"self-harm":         "Content promotes self-harm",
	"violence":          "Content contains violence",
	"sexual-minors":     "Content involves minors in sexual contexts",
	"hate-threating":    "Content contains threatening hate speech",
	"harassment-threating": "Content contains threatening harassment",
	"violence-graphic":  "Content contains graphic violence",
}

func (c *openaiChecker) CheckText(ctx context.Context, text, lang string) (Decision, error) {
	body, err := json.Marshal(moderationRequest{Input: text})
	if err != nil {
		return Decision{Allowed: false, Reason: "internal error"}, fmt.Errorf("marshal moderation request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.openai.com/v1/moderations", bytes.NewReader(body))
	if err != nil {
		return Decision{Allowed: false, Reason: "internal error"}, fmt.Errorf("create moderation request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.apiKey)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		// Fail closed: if the API is unreachable, refuse the content.
		return Decision{Allowed: false, Reason: "content moderation service is temporarily unavailable"}, fmt.Errorf("moderation API request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return Decision{Allowed: false, Reason: "content moderation service error"}, fmt.Errorf("read moderation response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		// Fail closed on non-200 responses.
		return Decision{Allowed: false, Reason: "content moderation service error"},
			fmt.Errorf("moderation API returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var modResp moderationResponse
	if err := json.Unmarshal(respBody, &modResp); err != nil {
		return Decision{Allowed: false, Reason: "content moderation service error"},
			fmt.Errorf("unmarshal moderation response: %w", err)
	}

	if len(modResp.Results) == 0 {
		return Decision{Allowed: false, Reason: "content moderation service error"},
			fmt.Errorf("moderation API returned empty results")
	}

	result := modResp.Results[0]

	if !result.Flagged {
		return Decision{Allowed: true}, nil
	}

	// Build a plain-language reason from the flagged categories.
	reason := buildReason(result.Categories)
	return Decision{Allowed: false, Reason: reason}, nil
}

// buildReason constructs a user-facing reason from the flagged categories.
// Returns at most one category name in plain language (PRD §6.4).
func buildReason(categories map[string]bool) string {
	// Priority order: most severe first.
	priority := []string{
		"sexual-minors",
		"hate-threating",
		"harassment-threating",
		"violence-graphic",
		"self-harm",
		"sexual",
		"hate",
		"harassment",
		"violence",
	}
	for _, cat := range priority {
		if flagged, ok := categories[cat]; ok && flagged {
			if msg, ok := humanReadable[cat]; ok {
				return msg
			}
		}
	}
	return "Content violates safety guidelines"
}
