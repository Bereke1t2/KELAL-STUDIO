import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

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
// TODO(auth-gate): once session state exists beyond a single login call,
// wire a `GoRouterRefreshStream` fed by the auth Bloc's state stream into
// `redirect:` here so logout auto-redirects to `/login` — do not scatter
// ad-hoc auth checks into individual pages.
@lazySingleton
class AppRouter {
  late final GoRouter config = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
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
    ],
  );
}
