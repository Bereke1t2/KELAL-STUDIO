import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/notifications/local_notification_scheduler.dart';
import 'package:kelal_studio/core/router/app_router.dart';
import 'package:path_provider/path_provider.dart';

/// Shared app entrypoint logic, called by each `main_*.dart` flavor entry.
/// Keep this free of anything synchronous/heavy before [runApp] — deferred,
/// non-critical init belongs post-first-frame instead
/// (mobile/.claude/skills/flutter-performance/SKILL.md).
Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorageDirectory.web
        : HydratedStorageDirectory(
            (await getApplicationDocumentsDirectory()).path,
          ),
  );

  await configureDependencies();

  await getIt<LocalNotificationScheduler>().init();
  _wireReminderTapDeepLink();

  runApp(builder());
}

/// PRD §8.5: tapping a fired reminder notification deep-links into the app.
///
/// **Scope note (flagged, not silently narrowed):** this navigates to the
/// Drafts tab, not directly to `/export` for the specific draft. Two real
/// constraints rule out going further automatically: (1) `DraftsRepository`
/// exposes only a reactive `watchAll()`, no `getById`, and (2)
/// `/canvas-editor`/`/export`'s `CanvasScene` payload is `GoRouterState.extra`
/// — in-memory only, and (per `AppRouter`'s own redirect guards) not
/// reconstructable from a cold app launch the way a notification tap often
/// is. Landing on Drafts (where the reminded draft is one tap away, via the
/// same resume flow `DraftsPage` already offers) is the honest stopping
/// point given those two gaps, rather than a route that would silently
/// crash or resume the wrong draft.
void _wireReminderTapDeepLink() {
  getIt<LocalNotificationScheduler>().onNotificationTapped.listen((_) {
    getIt<AppRouter>().config.go('/drafts');
  });
}
