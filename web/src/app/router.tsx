import { BrowserRouter, Navigate, Route, Routes } from 'react-router';

import { PlaceholderPage } from '../features/PlaceholderPage';
import { BrandKitPage } from '../features/brandKit/BrandKitPage';
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
 * mobile-only, so there is deliberately no generation route. The Brand Kit and
 * admin screens are placeholders until their feature branches replace them.
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
            {/* A bad URL while signed in is a normal way to arrive. */}
            <Route path="*" element={<Navigate to="/brand-kit" replace />} />
          </Route>
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
