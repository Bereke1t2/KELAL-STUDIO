import { Navigate, Outlet, useLocation } from 'react-router';

import { useAuth } from '../auth/AuthContext';
import { useTranslation } from '../i18n/I18nContext';
import { Spinner } from '../ui/Spinner';

/**
 * Layout route for everything behind sign-in.
 *
 * `loading` renders neither the app nor a redirect: the provider is exchanging
 * a refresh token at that moment, and redirecting to /login first would flash
 * it at an already-authenticated admin on every reload.
 *
 * A rendering decision only — the server rejects an unauthenticated request
 * regardless of what the client draws. Never treat this as the security
 * boundary.
 */
export function ProtectedRoute() {
  const { status } = useAuth();
  const { t } = useTranslation();
  const location = useLocation();

  if (status === 'loading') {
    return (
      <div className="grid min-h-dvh place-items-center bg-canvas">
        <Spinner label={t('state.loading')} />
      </div>
    );
  }

  if (status === 'authenticated') return <Outlet />;

  return (
    <Navigate
      to="/login"
      replace
      state={{ from: location.pathname + location.search }}
    />
  );
}
