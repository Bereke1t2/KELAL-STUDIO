import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/router/app_shell.dart';
import 'package:kelal_studio/core/router/go_router_refresh_stream.dart';
import 'package:kelal_studio/core/router/placeholder_page.dart';
import 'package:kelal_studio/features/auth/domain/repositories/auth_repository.dart';
import 'package:kelal_studio/features/auth/presentation/pages/login_page.dart';
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
                builder: (context, state) => ComingSoonPage(
                  title: AppLocalizations.of(context).navComposeLabel,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/drafts',
                builder: (context, state) => ComingSoonPage(
                  title: AppLocalizations.of(context).navDraftsLabel,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/brand',
                builder: (context, state) => ComingSoonPage(
                  title: AppLocalizations.of(context).navBrandLabel,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                // Real SettingsPage — feat/settings-polish (Track C, merged
                // to main ahead of this branch's rebase) already built it,
                // so this starts real rather than as another
                // ComingSoonPage, unlike the three tabs above.
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

  final goingToLogin = matchedLocation == AppRouter.loginLocation;
  if (!isAuthenticated && !goingToLogin) return AppRouter.loginLocation;
  if (isAuthenticated && goingToLogin) return AppRouter.homeLocation;
  return null;
}
