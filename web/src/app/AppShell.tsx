import { NavLink, Outlet } from 'react-router';

import { useAuth } from '../auth/AuthContext';
import { useTranslation } from '../i18n/I18nContext';
import type { MessageKey } from '../i18n/messages';
import { Button } from '../ui/Button';
import { LanguageToggle } from '../ui/LanguageToggle';
import { ThemeToggle } from '../ui/ThemeToggle';
import { Wordmark } from '../ui/Wordmark';

/**
 * Portal chrome: a left rail and a content column.
 *
 * The nav is grouped under "Brand" and "Oversight" — the portal's only two
 * concerns (PRD §4). That grouping is information, not decoration: it tells the
 * reader which half of the portal they are in.
 *
 * Every nav item is shown to every signed-in user. The `is_admin` token claim
 * is unverified client-side (api/claims.ts), so hiding on it buys no security;
 * a non-admin who follows an admin link gets the server's 403 rendered as
 * plain language. The server is the boundary.
 */
const GROUPS: ReadonlyArray<{
  labelKey: MessageKey;
  items: ReadonlyArray<{ to: string; labelKey: MessageKey }>;
}> = [
  {
    labelKey: 'nav.group.brand',
    items: [{ to: '/brand-kit', labelKey: 'nav.brandKit' }],
  },
  {
    labelKey: 'nav.group.oversight',
    items: [
      { to: '/admin/usage', labelKey: 'nav.usage' },
      { to: '/admin/flags', labelKey: 'nav.flags' },
      { to: '/admin/users', labelKey: 'nav.users' },
    ],
  },
];

export function AppShell() {
  const { claims, logout } = useAuth();
  const { t } = useTranslation();

  return (
    <div className="min-h-dvh bg-canvas text-ink md:grid md:grid-cols-[15rem_1fr]">
      <aside className="flex flex-col gap-6 border-b border-line bg-surface p-5 md:sticky md:top-0 md:h-dvh md:border-r md:border-b-0">
        <NavLink to="/brand-kit" className="rounded-md">
          <Wordmark size="sm" />
        </NavLink>

        <nav aria-label={t('nav.sections')} className="flex flex-col gap-5">
          {GROUPS.map((group) => (
            <div key={group.labelKey} className="flex flex-col gap-1">
              <p className="px-3 text-caption uppercase tracking-[0.12em] text-ink-tertiary">
                {t(group.labelKey)}
              </p>
              <ul className="flex flex-col gap-0.5">
                {group.items.map((item) => (
                  <li key={item.to}>
                    <NavLink
                      to={item.to}
                      className={({ isActive }) =>
                        [
                          'flex min-h-11 items-center rounded-md px-3 text-body-sm transition-colors',
                          'motion-reduce:transition-none',
                          isActive
                            ? 'bg-brand-subtle text-tertiary-text'
                            : 'text-ink-secondary hover:bg-brand-subtle hover:text-ink',
                        ].join(' ')
                      }
                    >
                      {t(item.labelKey)}
                    </NavLink>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </nav>

        <div className="flex flex-col gap-3 md:mt-auto">
          <ThemeToggle />
          <LanguageToggle />
          <div className="border-t border-line-subtle pt-3">
            {claims?.email ? (
              <p className="truncate px-1 text-caption text-ink-tertiary">
                {claims.email}
              </p>
            ) : null}
            <Button
              variant="tertiary"
              block
              onClick={logout}
              className="justify-start px-1"
            >
              {t('action.signOut')}
            </Button>
          </div>
        </div>
      </aside>

      <main className="min-w-0 px-5 py-8 md:px-10 md:py-12">
        <div className="mx-auto max-w-3xl">
          <Outlet />
        </div>
      </main>
    </div>
  );
}
