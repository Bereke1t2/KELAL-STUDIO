/**
 * Access/refresh token storage for the portal.
 *
 * FLAG — storage choice needs a security decision (PRD §7.8).
 *
 * The access token is held in memory only, so it never survives a tab close
 * and is not readable from storage. The refresh token has to outlive a reload
 * for "stay logged in" to work at all, and the backend returns it in a JSON
 * body rather than setting an httpOnly cookie — so an SPA has nowhere better
 * than Web Storage to put it, which means an XSS on this origin can exfiltrate
 * it. sessionStorage is used rather than localStorage to at least scope the
 * exposure to one tab/session.
 *
 * The real fix is server-side: issue the refresh token as an httpOnly,
 * SameSite cookie so script can never read it. That is a backend change and a
 * contract change, so it is flagged here rather than decided here.
 */

const REFRESH_KEY = 'kelal.refresh_token';

let accessToken: string | null = null;

export const tokens = {
  getAccess: (): string | null => accessToken,

  getRefresh(): string | null {
    try {
      return sessionStorage.getItem(REFRESH_KEY);
    } catch {
      // Storage can throw outright (Safari private mode, blocked site data).
      return null;
    }
  },

  set(access: string, refresh: string): void {
    accessToken = access;
    try {
      sessionStorage.setItem(REFRESH_KEY, refresh);
    } catch {
      // Non-fatal: the session still works until this tab is closed.
    }
  },

  clear(): void {
    accessToken = null;
    try {
      sessionStorage.removeItem(REFRESH_KEY);
    } catch {
      // Nothing to do — the in-memory token is already gone.
    }
  },
};
