import type { ReactElement, ReactNode } from 'react';
import { render } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router';

import { AuthProvider } from '../auth/AuthContext';
import { I18nProvider } from '../i18n/I18nContext';
import { ThemeProvider } from '../theme/ThemeContext';

function Providers({ children }: { children: ReactNode }) {
  return (
    <ThemeProvider>
      <I18nProvider>
        <AuthProvider>{children}</AuthProvider>
      </I18nProvider>
    </ThemeProvider>
  );
}

/**
 * Render `ui` at `path` inside all app providers and a MemoryRouter.
 * `initialEntries` seeds the history (use it to pass `?token=…` etc.).
 */
export function renderWithProviders(
  ui: ReactElement,
  { path = '/', initialEntries = [path] }: { path?: string; initialEntries?: string[] } = {},
) {
  return render(
    <Providers>
      <MemoryRouter initialEntries={initialEntries}>
        <Routes>
          <Route path={path} element={ui} />
          <Route path="*" element={<div data-testid="redirected" />} />
        </Routes>
      </MemoryRouter>
    </Providers>,
  );
}
