import { BrowserRouter, Navigate, Route, Routes } from 'react-router';

import { PlaceholderPage } from '../features/PlaceholderPage';
import { AppShell } from './AppShell';
import { ProtectedRoute } from './ProtectedRoute';

/**
 * Portal routes.
 *
 * Scope is Brand Kit + admin (PRD §4, §5.6) — the composer is mobile-only, so
 * there is deliberately no generation route here. The screens are placeholders
 * until `feat/web-brand-kit-and-preview` and `feat/web-admin` replace them
 * route by route; `feat/web-self-serve-auth` adds the public routes around the
 * protected subtree.
 */
export function AppRouter() {
  return (
    <BrowserRouter>
      <ProtectedRoute>
        <Routes>
          {/* Layout route: the shell renders once and persists across
              navigations, so theme/locale state and focus are not torn down. */}
          <Route element={<AppShell />}>
            <Route index element={<Navigate to="/brand-kit" replace />} />
            <Route
              path="/brand-kit"
              element={
                <PlaceholderPage
                  eyebrowKey="nav.group.brand"
                  titleKey="nav.brandKit"
                />
              }
            />
            <Route
              path="/admin/usage"
              element={
                <PlaceholderPage
                  eyebrowKey="nav.group.oversight"
                  titleKey="nav.usage"
                />
              }
            />
            <Route
              path="/admin/flags"
              element={
                <PlaceholderPage
                  eyebrowKey="nav.group.oversight"
                  titleKey="nav.flags"
                />
              }
            />
            <Route
              path="/admin/users"
              element={
                <PlaceholderPage
                  eyebrowKey="nav.group.oversight"
                  titleKey="nav.users"
                />
              }
            />
            {/* A bad URL is a normal way to arrive; send it somewhere real. */}
            <Route path="*" element={<Navigate to="/brand-kit" replace />} />
          </Route>
        </Routes>
      </ProtectedRoute>
    </BrowserRouter>
  );
}
