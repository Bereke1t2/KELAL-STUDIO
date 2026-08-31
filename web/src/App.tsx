/**
 * Root of the Kelal Studio web management portal.
 *
 * Scope is deliberately narrow (PRD §4): Brand Kit configuration and admin
 * oversight. The composer lives on mobile — this portal never generates
 * content, and under the descope ladder (PRD §5.6) it collapses to
 * Admin + Brand Kit only, which is exactly what is built here.
 *
 * Providers wrap the router: theme, locale, and auth state must outlive any
 * single screen so they are not torn down on navigation.
 */
import { AppRouter } from './app/router';
import { AuthProvider } from './auth/AuthContext';
import { I18nProvider } from './i18n/I18nContext';
import { ThemeProvider } from './theme/ThemeContext';

export function App() {
  return (
    <ThemeProvider>
      <I18nProvider>
        <AuthProvider>
          <AppRouter />
        </AuthProvider>
      </I18nProvider>
    </ThemeProvider>
  );
}
