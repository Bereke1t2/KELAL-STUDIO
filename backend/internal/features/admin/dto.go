package admin

import (
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// DTOs are the admin API's wire shapes. Admin is backend-only (not in the mobile
// contract), so these types and api/openapi.yaml's admin section define the
// schema together — there is no generated mobile client to stay byte-compatible
// with. Even so, models are never serialized raw: handlers map them through these
// types so internal columns never leak onto the wire.

// usageResponse is the body of GET /admin/usage.
type usageResponse struct {
	TotalUsers       int64 `json:"total_users"`
	TotalGenerations int64 `json:"total_generations"`
	TextGenerations  int64 `json:"text_generations"`
	ImageGenerations int64 `json:"image_generations"`
	VideoGenerations int64 `json:"video_generations"`
	TotalFlags       int64 `json:"total_flags"`
	PendingFlags     int64 `json:"pending_flags"`
}

func toUsageResponse(s UsageSummary) usageResponse {
	// usageResponse mirrors UsageSummary field-for-field (only json tags differ),
	// so a direct conversion IS the field-by-field copy (staticcheck S1016). The
	// mappers below stay explicit because they project a SUBSET of a model.
	return usageResponse(s)
}

// flagResponse is one moderation flag in the review queue. reviewed_by_admin_id
// and reviewed_at are null until an admin adjudicates it. The raw input_snapshot
// is included: this is an admin-only surface (PRD §6.13), so — unlike the
// user-facing moderation error, which never echoes the offending input — the
// review queue needs to show what tripped the filter.
type flagResponse struct {
	ID                uuid.UUID  `json:"id"`
	UserID            uuid.UUID  `json:"user_id"`
	InputSnapshot     string     `json:"input_snapshot"`
	Reason            string     `json:"reason"`
	ReviewedByAdminID *uuid.UUID `json:"reviewed_by_admin_id"`
	ReviewedAt        *time.Time `json:"reviewed_at"`
	CreatedAt         time.Time  `json:"created_at"`
}

func toFlagResponse(f *models.ModerationFlag) flagResponse {
	return flagResponse{
		ID:                f.ID,
		UserID:            f.UserID,
		InputSnapshot:     f.InputSnapshot,
		Reason:            f.Reason,
		ReviewedByAdminID: f.ReviewedByAdminID,
		ReviewedAt:        f.ReviewedAt,
		CreatedAt:         f.CreatedAt,
	}
}

// flagsResponse wraps the queue in an object (not a bare array) so the payload
// can grow — pagination, counts — without a breaking shape change.
type flagsResponse struct {
	Flags []flagResponse `json:"flags"`
}

func toFlagsResponse(flags []models.ModerationFlag) flagsResponse {
	out := make([]flagResponse, 0, len(flags))
	for i := range flags {
		out = append(out, toFlagResponse(&flags[i]))
	}
	return flagsResponse{Flags: out}
}

// setLimitsRequest is the body of PUT /admin/users/{id}/limits. Both fields are
// pointers so omitting one (or sending null) clears that override back to the
// global default, while a number sets it. Negative values are rejected by the
// service; zero is allowed (an explicit "block all").
type setLimitsRequest struct {
	DailyTextQuota  *int `json:"daily_text_quota"`
	DailyImageQuota *int `json:"daily_image_quota"`
}

func (r setLimitsRequest) toInput() LimitsInput {
	// setLimitsRequest and LimitsInput share the same two pointer fields, so this
	// is a direct conversion, not a field-by-field copy (staticcheck S1016).
	return LimitsInput(r)
}

// userLimitsResponse is the body returned by PUT /admin/users/{id}/limits: the
// resulting override state for the user. A null field means "no override — the
// global default applies".
type userLimitsResponse struct {
	UserID          uuid.UUID `json:"user_id"`
	DailyTextQuota  *int      `json:"daily_text_quota"`
	DailyImageQuota *int      `json:"daily_image_quota"`
}

func toUserLimitsResponse(u *models.User) userLimitsResponse {
	return userLimitsResponse{
		UserID:          u.ID,
		DailyTextQuota:  u.DailyTextQuota,
		DailyImageQuota: u.DailyImageQuota,
	}
}
