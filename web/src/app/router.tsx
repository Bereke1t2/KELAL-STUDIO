import { BrowserRouter } from 'react-router';

import { useAuth } from '../auth/AuthContext';
import { Button } from '../ui/Button';
import { ThemeToggle } from '../ui/ThemeToggle';
import { ProtectedRoute } from './ProtectedRoute';

/**
 * Portal routes.
 *
 * Teardown branch: the old screens are removed and the real ones (i18n shell,
 * self-serve auth, Brand Kit, admin) land in the branches stacked on top of
 * this. Scope stays Brand Kit + admin (PRD §4, §5.6) — the composer is
 * mobile-only, so there is deliberately no generation route here.
 */
export function AppRouter() {
  return (
    <BrowserRouter>
      <ProtectedRoute>
        <Placeholder />
      </ProtectedRoute>
    </BrowserRouter>
  );
}

function Placeholder() {
  const { claims, logout } = useAuth();
  return (
    <div className="min-h-dvh bg-canvas text-ink">
      <header className="flex flex-wrap items-center gap-4 border-b border-line bg-surface px-6 py-3">
        <span className="text-title">Kelal Studio</span>
        <span className="text-body-sm text-ink-tertiary">Portal</span>
        <div className="ms-auto flex items-center gap-4">
          <ThemeToggle />
          {claims?.email ? (
            <span className="text-body-sm text-ink-secondary">
              {claims.email}
            </span>
          ) : null}
          <Button variant="tertiary" onClick={logout}>
            Sign out
          </Button>
        </div>
      </header>
      <main className="p-6">
        <p className="text-body text-ink-secondary">
          The portal screens land in the branches stacked on top of this one.
        </p>
      </main>
    </div>
  );
}
