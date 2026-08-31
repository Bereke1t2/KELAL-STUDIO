/**
 * Wire types, transcribed from backend/api/openapi.yaml (the source of truth).
 *
 * Field names keep their snake_case wire form deliberately — renaming at the
 * boundary would mean maintaining a mapping layer that silently drifts from
 * the spec. Regenerate/revisit when the contract changes.
 */

export interface AuthTokens {
  access_token: string;
  refresh_token: string;
}

export interface RegisterResult {
  user_id: string;
  /** Whether the verification email dispatched; a transient failure here does
   *  not fail registration — the caller can request a resend. */
  verification_sent: boolean;
}

export interface VerifyEmailResult {
  verified: boolean;
}

export interface User {
  id: string;
  email: string;
  email_verified: boolean;
}

export interface BrandKit {
  id?: string;
  brand_name?: string;
  logo_asset_id?: string | null;
  primary_color_hex?: string;
  secondary_color_hex?: string;
  tone_of_voice?: string;
  contact_info?: string;
  updated_at?: string;
}

export interface Asset {
  id?: string;
  width?: number;
  height?: number;
  mime_type?: string;
  created_at?: string;
}

export interface Quota {
  text_calls_used?: number;
  text_calls_limit?: number;
  image_calls_used?: number;
  image_calls_limit?: number;
  resets_at?: string;
}

/**
 * Admin surface — transcribed from backend/api/openapi.yaml (all `implemented`).
 *
 * V1 analytics is intentionally coarse: whole-population counts only, no
 * time-buckets, no error rate, no latency, no queue depth. There is also no
 * list-users endpoint — user limits are set by pasting a user id.
 */
export interface AdminUsage {
  total_users?: number;
  total_generations?: number;
  text_generations?: number;
  image_generations?: number;
  video_generations?: number;
  total_flags?: number;
  pending_flags?: number;
}

export interface ModerationFlag {
  id?: string;
  user_id?: string;
  /** The raw text that tripped the filter. Admin-only; confidential (PRD §7.9).
   *  Render as plain text only. */
  input_snapshot?: string;
  reason?: string;
  reviewed_by_admin_id?: string | null;
  reviewed_at?: string | null;
  created_at?: string;
}

export interface ModerationFlagList {
  flags?: ModerationFlag[];
}

/**
 * Per-user daily caps. Each field is tri-state: `null` clears the override
 * (global default applies), `0` blocks all, a positive number sets a cap.
 * Negatives are rejected server-side (400).
 */
export interface SetUserLimitsRequest {
  daily_text_quota: number | null;
  daily_image_quota: number | null;
}

export interface UserLimits {
  user_id?: string;
  daily_text_quota?: number | null;
  daily_image_quota?: number | null;
}
