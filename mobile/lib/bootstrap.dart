import 'package:flutter/widgets.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:path_provider/path_provider.dart';

/// Shared app entrypoint logic, called by each `main_*.dart` flavor entry.
/// Keep this free of anything synchronous/heavy before [runApp] — deferred,
/// non-critical init belongs post-first-frame instead
/// (mobile/.claude/skills/flutter-performance/SKILL.md).
Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(
      (await getApplicationDocumentsDirectory()).path,
    ),
  );

  await configureDependencies();

  runApp(builder());
}
