import { ApiError, type ErrorResponse } from './errors';
import { tokens } from './tokens';
import type { AuthTokens } from './types';

/** All routes are mounted under /v1; the dev server proxies this origin. */
const BASE = '/v1';

interface RequestOptions {
  method?: string;
  body?: unknown;
  /** Skip the bearer header and the refresh-retry (login, register, reset). */
  anonymous?: boolean;
}

async function toApiError(res: Response): Promise<ApiError> {
  let body: ErrorResponse;
  try {
    body = (await res.json()) as ErrorResponse;
  } catch {
    // A non-JSON failure (gateway error, network appliance) still has to
    // reach the UI as the same shape everything else branches on.
    body = { error_code: 'internal', message: `Request failed (${res.status})` };
  }
  return new ApiError(res.status, body);
}

/**
 * Single-flight refresh.
 *
 * The backend rotates refresh tokens and treats presenting an already-rotated
 * token as compromise — it revokes the entire chain (PRD §6.1). Two requests
 * 401-ing at once and each refreshing independently would do exactly that and
 * log the user out. So concurrent callers share one in-flight refresh.
 */
let refreshInFlight: Promise<void> | null = null;

async function refresh(): Promise<void> {
  // Capture locally: the IIFE's `finally` clears the module-level slot, so
  // reading it back after the await would race with a fast rejection.
  const inFlight = (refreshInFlight ??= (async () => {
    try {
      const refreshToken = tokens.getRefresh();
      if (!refreshToken) throw new Error('no refresh token');
      const res = await fetch(`${BASE}/auth/refresh`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ refresh_token: refreshToken }),
      });
      if (!res.ok) throw await toApiError(res);
      const next = (await res.json()) as AuthTokens;
      tokens.set(next.access_token, next.refresh_token);
    } catch (err) {
      tokens.clear();
      throw err;
    } finally {
      refreshInFlight = null;
    }
  })());
  return inFlight;
}

async function send(path: string, opts: RequestOptions): Promise<Response> {
  const headers: Record<string, string> = {};
  if (opts.body !== undefined) headers['content-type'] = 'application/json';
  const access = tokens.getAccess();
  if (!opts.anonymous && access) headers.authorization = `Bearer ${access}`;

  return fetch(`${BASE}${path}`, {
    method: opts.method ?? 'GET',
    headers,
    ...(opts.body !== undefined ? { body: JSON.stringify(opts.body) } : {}),
  });
}

/**
 * Issue a request, refreshing once on an expired access token.
 *
 * Returns `null` for a 204/empty body so callers get a uniform shape rather
 * than a JSON parse error on a successful delete.
 */
export async function request<T>(
  path: string,
  opts: RequestOptions = {},
): Promise<T> {
  let res = await send(path, opts);

  if (res.status === 401 && !opts.anonymous && tokens.getRefresh()) {
    await refresh();
    res = await send(path, opts);
  }

  if (!res.ok) throw await toApiError(res);
  if (res.status === 204) return null as T;

  const text = await res.text();
  return (text ? JSON.parse(text) : null) as T;
}
