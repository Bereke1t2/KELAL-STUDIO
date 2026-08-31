/**
 * Access-token claims.
 *
 * FLAG — there is no user-profile endpoint in the contract. backend/api/
 * openapi.yaml exposes no GET /auth/me or /users/me, so after login the client
 * has tokens but no way to ASK who it is. The access token carries the
 * identity claims (backend platform/auth/jwt.go signs `email_verified`
 * alongside the subject), so the portal reads them from the token.
 *
 * This is for DISPLAY ONLY. The payload is base64, not encrypted, and is
 * trivially forgeable client-side — every real authorization decision is made
 * server-side against the signature. Never gate anything security-relevant on
 * these values; treat an `is_admin` here as "render the nav item", with the
 * server's 403 as the actual boundary.
 *
 * Add a /me endpoint server-side and this file goes away.
 */
export interface AccessClaims {
  sub?: string;
  email?: string;
  email_verified?: boolean;
  is_admin?: boolean;
  exp?: number;
}

/** Decode a JWT payload without verifying it. Returns null on anything odd. */
export function decodeClaims(token: string): AccessClaims | null {
  const payload = token.split('.')[1];
  if (!payload) return null;
  try {
    // base64url -> base64, then decode as UTF-8 so non-ASCII claims survive.
    const b64 = payload.replace(/-/g, '+').replace(/_/g, '/');
    const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    return JSON.parse(new TextDecoder().decode(bytes)) as AccessClaims;
  } catch {
    return null;
  }
}
