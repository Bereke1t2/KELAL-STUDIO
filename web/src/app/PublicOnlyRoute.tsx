import { Navigate, Outlet } from 'react-router';

import { useAuth } from '../auth/AuthContext';
import { AuthScreen } from '../features/auth/AuthScreen';

/**
 * Layout route for the unauthenticated screens (sign in, register, verify
 * email, password reset). A signed-in user has no business here — send them to
 * the portal. During the refresh-token exchange, render nothing rather than
 * flash a sign-in form.
 */
export function PublicOnlyRoute() {
  const { status } = useAuth();

  if (status === 'loading') return null;
  if (status === 'authenticated') return <Navigate to="/brand-kit" replace />;

  return (
    <AuthScreen>
      <Outlet />
    </AuthScreen>
  );
}
