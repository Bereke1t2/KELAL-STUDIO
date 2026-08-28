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

/*
 * FLAG — admin response shapes are NOT in the contract.
 *
 * All four /admin/* operations are declared `x-implementation-status: stub`
 * with a bare `'200': { description: OK }` and no schema, so there is no
 * server-side shape to transcribe. The interfaces below are this client's
 * PROPOSAL, derived from PRD §6.13 (user limits, usage analytics,
 * flagged-prompt audit log, queue health) — not an agreed contract.
 *
 * Do not treat them as settled: when the Admin slice is built, reconcile
 * these against whatever the backend actually returns and update
 * backend/api/openapi.yaml at the same time.
 */

export interface AdminUsage {
  generations_total?: number;
  error_rate?: number;
  latency_p50_ms?: number;
  latency_p95_ms?: number;
  queue_depth?: number;
}

export interface ModerationFlag {
  id?: string;
  user_id?: string;
  input_text?: string;
  input_lang?: string;
  reason?: string;
  reviewed?: boolean;
  created_at?: string;
}
