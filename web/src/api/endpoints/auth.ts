import { request } from '../client';
import { tokens } from '../tokens';
import type { AuthTokens, RegisterResult } from '../types';

/**
 * Auth operations (PRD §6.1). All are anonymous except account deletion.
 *
 * Registration does NOT establish a session — it returns a user id and
 * dispatches a verification email; the caller verifies, then logs in
 * (backend/docs/OPEN_QUESTIONS.md, register-verification, resolved
 * 2026-08-25). Any flow that assumes register logs you in is stale.
 */
export const authApi = {
  async login(email: string, password: string): Promise<void> {
    const t = await request<AuthTokens>('/auth/login', {
      method: 'POST',
      body: { email, password },
      anonymous: true,
    });
    tokens.set(t.access_token, t.refresh_token);
  },

  register: (email: string, password: string): Promise<RegisterResult> =>
    request<RegisterResult>('/auth/register', {
      method: 'POST',
      body: { email, password },
      anonymous: true,
    }),

  verifyEmail: (token: string): Promise<void> =>
    request<void>('/auth/verify-email', {
      method: 'POST',
      body: { token },
      anonymous: true,
    }),

  resendVerification: (email: string): Promise<void> =>
    request<void>('/auth/verify-email/resend', {
      method: 'POST',
      body: { email },
      anonymous: true,
    }),

  /** Always resolves the same way whether or not the email exists — the
   *  endpoint gives no enumeration signal (PRD §6.1), so neither does this. */
  requestPasswordReset: (email: string): Promise<void> =>
    request<void>('/auth/password-reset/request', {
      method: 'POST',
      body: { email },
      anonymous: true,
    }),

  confirmPasswordReset: (resetToken: string, newPassword: string): Promise<void> =>
    request<void>('/auth/password-reset/confirm', {
      method: 'POST',
      body: { reset_token: resetToken, new_password: newPassword },
      anonymous: true,
    }),

  deleteAccount: (): Promise<void> =>
    request<void>('/auth/account', { method: 'DELETE' }),

  logout(): void {
    tokens.clear();
  },
};
