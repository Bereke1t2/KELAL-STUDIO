import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/router/app_shell.dart';
import 'package:kelal_studio/core/router/go_router_refresh_stream.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/features/auth/domain/repositories/auth_repository.dart';
import 'package:kelal_studio/features/auth/presentation/pages/login_page.dart';
import 'package:kelal_studio/features/auth/presentation/pages/register_page.dart';
import 'package:kelal_studio/features/auth/presentation/pages/reset_password_confirm_page.dart';
import 'package:kelal_studio/features/auth/presentation/pages/reset_password_request_page.dart';
import 'package:kelal_studio/features/auth/presentation/widgets/email_verification_gate.dart';
import 'package:kelal_studio/features/brand_kit/presentation/pages/brand_kit_page.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/pages/canvas_editor_page.dart';
import 'package:kelal_studio/features/composer/presentation/pages/composer_page.dart';
import 'package:kelal_studio/features/drafts/presentation/pages/drafts_page.dart';
import 'package:kelal_studio/features/export/presentation/pages/export_page.dart';
import 'package:kelal_studio/features/quota/presentation/widgets/quota_status_badge.dart';
import 'package:kelal_studio/features/settings/presentation/pages/account_delete_confirm_page.dart';
import 'package:kelal_studio/features/settings/presentation/pages/account_delete_consequence_page.dart';
import 'package:kelal_studio/features/settings/presentation/pages/account_deleted_page.dart';
import 'package:kelal_studio/features/settings/presentation/pages/account_page.dart';
import 'package:kelal_studio/features/settings/presentation/pages/legal_document_page.dart';
import 'package:kelal_studio/features/settings/presentation/pages/legal_page.dart';
import 'package:kelal_studio/features/settings/presentation/pages/settings_page.dart';

/// Central route table. Kept as a plain [GoRouter] (string paths) for now —
/// adopt `go_router_builder` codegen once the navigation model stabilizes
/// past the first couple of features (see mobile/CLAUDE.md decisions log).
///
/// Auth-gated via [AuthRepository.watchIsAuthenticated]: a
/// [GoRouterRefreshStream] feeds `refreshListenable:`, and [redirect:]
/// (via the extracted, independently-testable [authRedirect]) sends an
/// unauthenticated user to `/login` and an authenticated one away from it —
/// the single place this decision is made, per the removed TODO's explicit
/// "do not scatter ad-hoc auth checks into individual pages" instruction.
@lazySingleton
class AppRouter {
  AppRouter(this._authRepository) {
    _refreshStream = GoRouterRefreshStream(
      _authRepository.watchIsAuthenticated(),
    );
  }

  final AuthRepository _authRepository;
  late final GoRouterRefreshStream _refreshStream;

  static const loginLocation = '/login';
  static const registerLocation = '/register';
  static const resetPasswordRequestLocation = '/reset-password';
  static const resetPasswordConfirmLocation = '/reset-password/confirm';

  /// Pushed on top of the shell from `ComposerPage` once
  /// `ImageGenerationSuccess` lands — not a `StatefulShellBranch` tab
  /// (nothing in the bottom nav points here directly), same top-level
  /// pattern as `registerLocation`/`resetPasswordRequestLocation`. Reached
  /// via `context.push(canvasEditorLocation, extra: CanvasEditorPageArgs(..))`:
  /// a `CanvasScene` holds a decoded `ui.Image`, which can't round-trip
  /// through a URL query param, so `GoRouterState.extra` (in-memory only) is
  /// the only viable way to hand it (plus the two caption strings riding
  /// alongside it) off — see `builder:` below.
  static const canvasEditorLocation = '/canvas-editor';

  /// Pushed from `CanvasEditorPage`'s Continue button once editing is done
  /// — same top-level, non-tab pattern as [canvasEditorLocation], and same
  /// `extra`-only reasoning (`ExportPageArgs` carries a `CanvasScene` too).
  static const exportLocation = '/export';

  /// Where an authenticated user lands after leaving `/login` — the
  /// Compose branch is this shell's designated home destination.
  static const homeLocation = '/compose';

  late final GoRouter config = GoRouter(
    initialLocation: loginLocation,
    refreshListenable: _refreshStream,
    redirect: (context, state) => authRedirect(
      isAuthenticated: _refreshStream.value,
      matchedLocation: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: loginLocation,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: registerLocation,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: resetPasswordRequestLocation,
        builder: (context, state) => const ResetPasswordRequestPage(),
      ),
      GoRoute(
        path: resetPasswordConfirmLocation,
        builder: (context, state) => const ResetPasswordConfirmPage(),
      ),
      GoRoute(
        path: canvasEditorLocation,
        // `extra` is in-memory only — go_router drops it whenever
        // navigation state is restored after process death (a routine
        // Android low-memory scenario, not a hypothetical), so a resumed
        // session landing here mid-restoration would otherwise hit a
        // null-check crash on the cast below. Bounce back to Compose
        // instead of crashing; a scene worth editing is only ever one
        // "Create graphic" tap away.
        redirect: (context, state) =>
            state.extra is CanvasEditorPageArgs ? null : homeLocation,
        builder: (context, state) =>
            CanvasEditorPage(args: state.extra! as CanvasEditorPageArgs),
      ),
      GoRoute(
        path: exportLocation,
        // Same process-death `extra`-drop guard as [canvasEditorLocation]
        // above, same reasoning — bounce to Compose rather than crash on
        // the cast below.
        redirect: (context, state) =>
            state.extra is ExportPageArgs ? null : homeLocation,
        builder: (context, state) =>
            ExportPage(args: state.extra! as ExportPageArgs),
      ),
      // Pushed from `SettingsPage` (see the `/settings` shell branch below)
      // rather than tabs themselves — kept as top-level routes, same
      // pattern later branches use for `/canvas-editor`/`/export`, since
      // these came in from feat/settings-polish (merged to main before
      // this branch's rebase) built against the pre-shell router; folded
      // in here rather than nested under the shell so a merge/rebase of
      // this stack onto main's settings work doesn't have to touch the
      // shell structure itself.
      GoRoute(
        path: '/settings/account',
        builder: (context, state) => const AccountPage(),
      ),
      GoRoute(
        path: '/settings/account_delete_consequence',
        builder: (context, state) => const AccountDeleteConsequencePage(),
      ),
      GoRoute(
        path: '/settings/account_delete_confirm',
        builder: (context, state) => const AccountDeleteConfirmPage(),
      ),
      GoRoute(
        path: '/settings/account_deleted',
        builder: (context, state) => const AccountDeletedPage(),
      ),
      GoRoute(
        path: '/settings/legal',
        builder: (context, state) => const LegalPage(),
      ),
      GoRoute(
        path: '/settings/legal_document',
        builder: (context, state) {
          final args = state.extra as Map<String, String>? ?? {};
          return LegalDocumentPage(
            title: args['title'] ?? 'Document',
            content: args['content'] ?? '',
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: homeLocation,
                // Compose is "the screen a signed-in user lands on" (PRD
                // §6.1) — gated behind email verification.
                //
                // QuotaStatusBadge sits above EmailVerificationGate,
                // not inside it — remaining quota (PRD §6.14: visible
                // *before* a generation attempt) isn't conditional on
                // verification status the way the generation UI itself
                // is, so it stays visible regardless of which state the
                // gate below it is showing.
                //
                // ComposerPage (feat/idea-composer-generation) replaces
                // the placeholder "Coming soon" text that used to fill
                // EmailVerificationGate's child slot — both wrappers
                // above it are unchanged from the quota branch.
                builder: (context, state) => Scaffold(
                  appBar: AppBar(
                    title: Text(AppLocalizations.of(context).navComposeLabel),
                  ),
                  body: const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          0,
                        ),
                        child: QuotaStatusBadge(),
                      ),
                      Expanded(
                        child: EmailVerificationGate(child: ComposerPage()),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                // Real DraftsPage — feat/local-drafts (PRD §10.5).
                path: '/drafts',
                builder: (context, state) => const DraftsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/brand',
                // Real Brand Kit UI (see BrandKitPage's own doc comment
                // for why this exists in mobile at all — a deliberate,
                // documented PRD deviation).
                builder: (context, state) => const BrandKitPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                // Real SettingsPage — feat/settings-polish (Track C).
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// The auth-gating decision, extracted from `redirect:` so it's testable
/// without spinning up a full [GoRouter]/`BuildContext` (see
/// mobile/.claude/skills/flutter-testing/SKILL.md).
///
/// [isAuthenticated] is `null` until [GoRouterRefreshStream] has received
/// its first emission (the initial secure-storage read inside
/// `AuthRepositoryImpl` is async) — no redirect happens while that's
/// unresolved, so the app just stays at `initialLocation` until the real
/// state is known, at which point the next `refreshListenable`
/// notification re-runs this and redirects if needed. This means an
/// already-authenticated user can see `/login` flash briefly on cold
/// start; there's no splash/loading route yet to avoid it (flagged as a
/// judgment call, not a silent gap).
@visibleForTesting
String? authRedirect({
  required bool? isAuthenticated,
  required String matchedLocation,
}) {
  if (isAuthenticated == null) return null;

  // Routes reachable by a signed-out user: /login plus the sign-up and
  // password-reset flows added alongside it. All behave the same way for
  // redirect purposes — an authenticated user is sent to `homeLocation`,
  // an unauthenticated user is left alone.
  const publicAuthLocations = {
    AppRouter.loginLocation,
    AppRouter.registerLocation,
    AppRouter.resetPasswordRequestLocation,
    AppRouter.resetPasswordConfirmLocation,
  };
  final isPublicAuthRoute = publicAuthLocations.contains(matchedLocation);
  if (!isAuthenticated && !isPublicAuthRoute) return AppRouter.loginLocation;
  if (isAuthenticated && isPublicAuthRoute) return AppRouter.homeLocation;
  return null;
}
