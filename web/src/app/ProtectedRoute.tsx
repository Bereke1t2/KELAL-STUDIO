import type { ReactNode } from 'react';

import { useAuth } from '../auth/AuthContext';
import { AuthScreen } from '../features/auth/AuthScreen';
import { LoginPage } from '../features/auth/LoginPage';
import { useTranslation } from '../i18n/I18nContext';

/**
 * Gate for everything behind sign-in.
 *
 * `loading` renders neither the app nor the login form: the provider is
 * exchanging a refresh token at that moment, and showing the login screen
 * first would flash it at an already-authenticated admin on every reload.
 *
 * This is a rendering decision only — the server rejects an unauthenticated
 * request regardless of what the client draws. `feat/web-self-serve-auth`
 * replaces the inline login with real public routes and a return-to redirect.
 */
export function ProtectedRoute({ children }: { children: ReactNode }) {
  const { status } = useAuth();
  const { t } = useTranslation();

  if (status === 'loading') {
    return (
      <div className="grid min-h-dvh place-items-center bg-canvas">
        <p className="text-body-sm text-ink-tertiary" role="status">
          {t('state.loading')}
        </p>
      </div>
    );
  }

  if (status === 'authenticated') return <>{children}</>;

  return (
    <AuthScreen>
      <LoginPage />
    </AuthScreen>
  );
}
