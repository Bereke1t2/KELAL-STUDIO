import { BrowserRouter, Navigate, Route, Routes } from 'react-router';

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
          <Route path="/" element={<Navigate to="/brand-kit" replace />} />
          <Route path="/brand-kit" element={<Placeholder title="Brand Kit" />} />
          <Route path="/admin/usage" element={<Placeholder title="Usage" />} />
          <Route path="/admin/flags" element={<Placeholder title="Flags" />} />
          <Route path="/admin/users" element={<Placeholder title="Users" />} />
          {/* A bad URL is a normal way to arrive; send it somewhere real
              rather than rendering nothing. */}
          <Route path="*" element={<Navigate to="/brand-kit" replace />} />
        </Routes>
      </ProtectedRoute>
    </BrowserRouter>
  );
}
