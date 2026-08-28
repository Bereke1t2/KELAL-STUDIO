import { BrowserRouter, Navigate, Route, Routes } from 'react-router';

import { FlagsPage } from '../features/admin/FlagsPage';
import { UsagePage } from '../features/admin/UsagePage';
import { BrandKitPage } from '../features/brandKit/BrandKitPage';
import { AppShell } from './AppShell';
import { ProtectedRoute } from './ProtectedRoute';

/**
 * Portal routes.
 *
 * Scope is Brand Kit + admin (PRD §4, §5.6) — the composer is mobile-only, so
 * there is deliberately no generation route here. Screens land in the branches
 * stacked on top of this one; each placeholder below is replaced, not added to.
 */
function Placeholder({ title }: { title: string }) {
  return <h1 className="text-2xl text-ink">{title}</h1>;
}

export function AppRouter() {
  return (
    <BrowserRouter>
      <ProtectedRoute>
        <Routes>
          {/* Layout route: the shell renders once and persists across
              navigations, so theme state and focus are not torn down. */}
          <Route element={<AppShell />}>
            <Route path="/" element={<Navigate to="/brand-kit" replace />} />
            <Route path="/brand-kit" element={<BrandKitPage />} />
            <Route path="/admin/usage" element={<UsagePage />} />
            <Route path="/admin/flags" element={<FlagsPage />} />
            <Route path="/admin/users" element={<Placeholder title="Users" />} />
            {/* A bad URL is a normal way to arrive; send it somewhere real
                rather than rendering nothing. */}
            <Route path="*" element={<Navigate to="/brand-kit" replace />} />
          </Route>
        </Routes>
      </ProtectedRoute>
    </BrowserRouter>
  );
}
