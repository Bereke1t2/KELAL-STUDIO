/**
 * The error taxonomy every backend failure renders to.
 *
 * Clients branch UI messaging on `error_code`, not on HTTP status alone —
 * that is what makes the PRD's "plain-language guidance" bar (§6.4, §11)
 * implementable instead of a generic failure screen.
 */

/** Contract-closed taxonomy (PRD §11). Treat these as stable. */
export const CLOSED_ERROR_CODES = [
  'quota_exceeded',
  'provider_timeout',
  'moderation_refused',
  'malformed_output',
  'validation_error',
] as const;

/**
 * Infrastructure/transport codes the backend also emits.
 *
 * FLAG (backend/docs/OPEN_QUESTIONS.md, error-code-enum): whether the client
 * keys off these or treats `error_code` as an open string is unresolved. This
 * client takes the open-string position — `ApiError.code` is typed as a union
 * WITH a string fallback, so an unrecognized code degrades to a generic
 * message instead of throwing. Do not narrow it to a closed union until that
 * item is decided.
 */
export const INFRA_ERROR_CODES = [
  'unauthorized',
  'forbidden',
  'email_not_verified',
  'not_found',
  'conflict',
  'rate_limited',
  'account_locked',
  'internal',
  'not_implemented',
] as const;

export type KnownErrorCode =
  | (typeof CLOSED_ERROR_CODES)[number]
  | (typeof INFRA_ERROR_CODES)[number];

/** Open by design — see the FLAG above. */
export type ErrorCode = KnownErrorCode | (string & {});

export interface ErrorResponse {
  error_code: ErrorCode;
  message: string;
  /** Present only for `quota_exceeded`. */
  resets_at?: string;
}

export class ApiError extends Error {
  readonly code: ErrorCode;
  readonly status: number;
  readonly resetsAt: string | undefined;

  constructor(status: number, body: ErrorResponse) {
    super(body.message);
    this.name = 'ApiError';
    this.code = body.error_code;
    this.status = status;
    this.resetsAt = body.resets_at;
  }

  /** A failure the caller can fix by re-authenticating. */
  get isAuthFailure(): boolean {
    return this.code === 'unauthorized' || this.status === 401;
  }

  /** A route that exists but is not built yet — every /admin/* today. */
  get isNotImplemented(): boolean {
    return this.code === 'not_implemented' || this.status === 501;
  }
}
