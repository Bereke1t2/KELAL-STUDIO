import { NavLink, Outlet } from 'react-router';

import { useAuth } from '../auth/AuthContext';
import { Button } from '../ui/Button';
import { ThemeToggle } from '../ui/ThemeToggle';

/**
 * Portal chrome: identity, theme control, sign-out, and the section nav.
 *
 * The nav lists Brand Kit and the three admin sections — the whole of PRD §4's
 * web surface. Admin links are shown to every signed-in user rather than
 * hidden behind the token's `is_admin` claim: those claims are unverified
 * client-side (see api/claims.ts) so hiding on them buys no security, and a
 * non-admin who follows one gets the server's 403 rendered as plain language.
 * Hiding would only make the portal feel broken to someone who *is* an admin
 * whose claim failed to decode.
 */
const SECTIONS: ReadonlyArray<{ to: string; label: string }> = [
  { to: '/brand-kit', label: 'Brand Kit' },
  { to: '/admin/usage', label: 'Usage' },
  { to: '/admin/flags', label: 'Flagged prompts' },
  { to: '/admin/users', label: 'Users' },
];

export function AppShell() {
  const { claims, logout } = useAuth();

  return (
    <div className="min-h-dvh bg-canvas text-ink">
      <header className="flex flex-wrap items-center gap-4 border-b border-line bg-surface px-6 py-3">
        <span className="text-lg">Kelal Studio</span>
        <span className="text-sm text-ink-tertiary">Portal</span>
        <div className="ms-auto flex items-center gap-4">
          <ThemeToggle />
          {claims?.email ? (
            <span className="text-sm text-ink-secondary">{claims.email}</span>
          ) : null}
          <Button variant="tertiary" onClick={logout}>
            Sign out
          </Button>
        </div>
      </header>

      <div className="flex flex-col gap-6 p-6 md:flex-row">
        <nav aria-label="Sections" className="md:w-56 md:shrink-0">
          <ul className="flex flex-wrap gap-1 md:flex-col">
            {SECTIONS.map((s) => (
              <li key={s.to}>
                <NavLink
                  to={s.to}
                  className={({ isActive }) =>
                    [
                      'block rounded-md px-4 py-3 text-sm',
                      isActive
                        ? 'bg-brand-subtle text-tertiary-text'
                        : 'text-ink-secondary hover:bg-brand-subtle',
                    ].join(' ')
                  }
                >
                  {s.label}
                </NavLink>
              </li>
            ))}
          </ul>
        </nav>

        <main className="min-w-0 flex-1">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
