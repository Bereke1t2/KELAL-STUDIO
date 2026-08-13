import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/di/injection.config.dart';

final getIt = GetIt.instance;

/// Aggregates every `@injectable`/`@lazySingleton`/`@module` registration
/// across `core/` and `features/**` into one generated `getIt.init()` call.
/// Run `dart run build_runner build --delete-conflicting-outputs` after
/// adding or changing any injectable class — see mobile/CLAUDE.md.
@InjectableInit(preferRelativeImports: true, asExtension: false)
Future<void> configureDependencies() async => init(getIt);
