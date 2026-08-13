import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/features/auth/presentation/pages/login_page.dart';

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
    ],
  );
}
