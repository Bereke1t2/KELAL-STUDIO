import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:injectable/injectable.dart';

/// Whether the user has already dismissed PRD §6.11's required first-run
/// instructional overlay (teaches the long-press-to-paste step on
/// `ExportPage`). A trivial persisted boolean UI flag — exactly the
/// `HydratedCubit` case `mobile/.claude/skills/flutter-state-management/SKILL.md`
/// calls out ("small, non-sensitive UI preferences"), same pattern as
/// `ThemeCubit`/`LocaleCubit` (`core/theme/theme_cubit.dart`,
/// `core/l10n/locale_cubit.dart`) — not a Bloc, since there's no async
/// operation or domain logic to sequence, just a direct-method-call flag
/// flip.
@lazySingleton
class ExportOverlaySeenCubit extends HydratedCubit<bool> {
  ExportOverlaySeenCubit() : super(false);

  void markSeen() => emit(true);

  @override
  bool? fromJson(Map<String, dynamic> json) => json['seen'] as bool?;

  @override
  Map<String, dynamic>? toJson(bool state) => {'seen': state};
}
