import { ApiError } from '../api/errors';
import type { TranslateFn } from '../i18n/messages';

/**
 * Turn a thrown value into copy a non-technical admin can act on.
 *
 * PRD acceptance criterion 7: failures must produce plain-language guidance,
 * never a raw technical error. The backend already returns a localized,
 * plain-language `message` for the cases it can phrase — that is preferred
 * verbatim (the `default` branch); this only supplies copy where the server's
 * wording would be unhelpful on its own or where nothing reached the server.
 *
 * Takes `t` rather than calling a hook so it can run inside a `catch`.
 */
export function errorMessage(err: unknown, t: TranslateFn): string {
  if (err instanceof ApiError) {
    switch (err.code) {
      case 'unauthorized':
        return t('error.session');
      case 'forbidden':
        return t('error.forbidden');
      case 'email_not_verified':
        return t('error.emailNotVerified');
      case 'account_locked':
        return t('error.accountLocked');
      case 'rate_limited':
        return t('error.rateLimited');
      case 'quota_exceeded':
        return err.resetsAt
          ? t('error.quota', { time: new Date(err.resetsAt).toLocaleString() })
          : t('error.quotaNoTime');
      case 'internal':
        return t('error.server');
      default:
        // A closed-taxonomy or otherwise phrased failure — trust the server's
        // own localized wording.
        return err.message;
    }
  }
  // A network failure never reaches the server, so there is no error_code to
  // branch on — the one case with no backend wording to defer to.
  return t('error.network');
}
