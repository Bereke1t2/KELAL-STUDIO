import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges an auth-session [Stream<bool>] into go_router's
/// `refreshListenable:` so a `redirect:` callback gets re-evaluated every
/// time the session state changes.
///
/// go_router 14.8.1 (pinned — see mobile/CLAUDE.md's exact-version policy)
/// does not itself export a `GoRouterRefreshStream` class (that convenience
/// wrapper only ships in newer go_router releases); this is the same
/// well-known pattern reimplemented locally, with one addition: [value]
/// caches the most recently emitted state so `AppRouter`'s `redirect:`
/// callback can read it synchronously (go_router calls `redirect:`
/// eagerly/synchronously on every navigation; making it `async` just to
/// read one boolean would add a needless extra frame).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<bool> stream) {
    _subscription = stream.listen((isAuthenticated) {
      value = isAuthenticated;
      notifyListeners();
    });
  }

  /// The most recently emitted auth state, or `null` if the underlying
  /// stream hasn't emitted yet (e.g. the initial secure-storage read is
  /// still in flight when the app first launches).
  bool? value;

  late final StreamSubscription<bool> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
