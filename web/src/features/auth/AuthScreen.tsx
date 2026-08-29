import type { ReactNode } from 'react';

import { LanguageToggle } from '../../ui/LanguageToggle';
import { ThemeToggle } from '../../ui/ThemeToggle';
import { Wordmark } from '../../ui/Wordmark';

/**
 * Shared frame for every unauthenticated screen (sign in, register, verify
 * email, password reset).
 *
 * The wordmark leads; language and theme controls sit top-right so they are
 * reachable before an account exists. The card is flat — surface, one
 * hairline, radius-lg — with generous padding.
 */
export function AuthScreen({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-dvh bg-canvas text-ink">
      <div className="mx-auto flex min-h-dvh max-w-md flex-col px-4 py-8">
        <div className="flex items-start justify-between gap-4">
          <Wordmark size="md" />
          <div className="flex flex-col items-end gap-2">
            <LanguageToggle />
            <ThemeToggle />
          </div>
        </div>

        <main className="flex flex-1 flex-col justify-center py-10">
          <div className="rounded-lg border border-line bg-surface p-8">
            {children}
          </div>
        </main>
      </div>
    </div>
  );
}
