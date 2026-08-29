import { BrowserRouter, Navigate, Route, Routes } from 'react-router';

import { BrandKitPage } from '../features/brandKit/BrandKitPage';
import { FlagsPage } from '../features/admin/FlagsPage';
import { UsagePage } from '../features/admin/UsagePage';
import { UsersPage } from '../features/admin/UsersPage';
import { ForgotPasswordPage } from '../features/auth/ForgotPasswordPage';
import { LoginPage } from '../features/auth/LoginPage';
import { RegisterPage } from '../features/auth/RegisterPage';
import { ResetPasswordPage } from '../features/auth/ResetPasswordPage';
import { VerifyEmailPage } from '../features/auth/VerifyEmailPage';
import { AppShell } from './AppShell';
import { ProtectedRoute } from './ProtectedRoute';
import { PublicOnlyRoute } from './PublicOnlyRoute';

/**
 * Portal routes.
 *
 * Two subtrees: the public auth screens under <PublicOnlyRoute> (which redirects
 * a signed-in user to the portal), and everything else under <ProtectedRoute>
 * (which redirects an anonymous visitor to /login, remembering where they were
 * headed). Scope is Brand Kit + admin (PRD §4, §5.6) — the composer is
 * mobile-only, so there is deliberately no generation route.
 */
export function AppRouter() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<PublicOnlyRoute />}>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/verify-email" element={<VerifyEmailPage />} />
          <Route path="/forgot-password" element={<ForgotPasswordPage />} />
          <Route path="/reset-password" element={<ResetPasswordPage />} />
        </Route>

        <Route element={<ProtectedRoute />}>
          {/* Layout route: the shell renders once and persists across
              navigations, so theme/locale state and focus are not torn down. */}
          <Route element={<AppShell />}>
            <Route index element={<Navigate to="/brand-kit" replace />} />
            <Route path="/brand-kit" element={<BrandKitPage />} />
            <Route path="/admin/usage" element={<UsagePage />} />
            <Route path="/admin/flags" element={<FlagsPage />} />
            <Route path="/admin/users" element={<UsersPage />} />
            {/* A bad URL while signed in is a normal way to arrive. */}
            <Route path="*" element={<Navigate to="/brand-kit" replace />} />
          </Route>
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
