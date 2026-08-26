import type { ReactNode } from 'react';

import { useAuth } from '../auth/AuthContext';
import { LoginPage } from '../features/auth/LoginPage';

/**
 * Gate for everything behind sign-in.
 *
 * `loading` renders neither the app nor the login form: the provider is
 * exchanging a refresh token at that moment, and showing the login screen
 * first would flash it at an already-authenticated admin on every reload.
 *
 * This is a rendering decision only. The server rejects an unauthenticated
 * request regardless of what the client chooses to draw — never treat this
 * component as the security boundary.
 */
export function ProtectedRoute({ children }: { children: ReactNode }) {
  const { status } = useAuth();

  if (status === 'loading') {
    return (
      <div className="grid min-h-dvh place-items-center bg-canvas">
        <p className="text-ink-tertiary" role="status">
          Loading…
        </p>
      </div>
    );
  }

  return status === 'authenticated' ? <>{children}</> : <LoginPage />;
}
