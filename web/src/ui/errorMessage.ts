import { ApiError } from '../api/errors';

/**
 * Turn a thrown value into copy a non-technical admin can act on.
 *
 * PRD acceptance criterion 7: failures must produce plain-language guidance,
 * never a raw technical error. The backend already returns a localized,
 * plain-language `message` for the cases it can phrase — so that is preferred
 * verbatim, and this only supplies copy where the server's wording would be
 * unhelpful on its own or where nothing reached the server at all.
 */
export function errorMessage(err: unknown): string {
  if (err instanceof ApiError) {
    switch (err.code) {
      case 'not_implemented':
        // Every /admin/* route today. Say so plainly instead of showing a 501.
        return 'This part of the portal is not built yet.';
      case 'unauthorized':
        return 'Your session expired. Please sign in again.';
      case 'forbidden':
        return 'Your account does not have access to this.';
      case 'email_not_verified':
        return 'Verify your email address before continuing.';
      case 'account_locked':
        return 'This account is temporarily locked after too many failed sign-in attempts.';
      case 'rate_limited':
        return 'Too many requests. Wait a moment and try again.';
      case 'quota_exceeded':
        return err.resetsAt
          ? `Quota used up. It resets at ${new Date(err.resetsAt).toLocaleString()}.`
          : 'Quota used up.';
      case 'internal':
        return 'Something went wrong on our end. Please try again.';
      default:
        return err.message;
    }
  }
  // A network failure never reaches the server, so there is no error_code to
  // branch on — this is the one case with no backend wording to defer to.
  return 'Could not reach the server. Check your connection and try again.';
}
