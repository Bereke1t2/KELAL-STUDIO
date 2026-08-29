import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:injectable/injectable.dart';

/// Whether the user has already dismissed PRD §6.10's required first-run
/// disclosure that uninstalling the app destroys all local drafts. A
/// trivial persisted boolean UI flag — exactly the `HydratedCubit` case
/// `mobile/.claude/skills/flutter-state-management/SKILL.md` calls out
/// ("small, non-sensitive UI preferences"), same pattern as
/// `ThemeCubit`/`LocaleCubit` (`core/theme/theme_cubit.dart`,
/// `core/l10n/locale_cubit.dart`) and — the direct precedent this mirrors
/// — `features/export/presentation/cubit/export_overlay_seen_cubit.dart`'s
/// `ExportOverlaySeenCubit`. Not a Bloc, since there's no async operation
/// or domain logic to sequence, just a direct-method-call flag flip.
@lazySingleton
class DraftsDisclosureSeenCubit extends HydratedCubit<bool> {
  DraftsDisclosureSeenCubit() : super(false);

  void markSeen() => emit(true);

  @override
  bool? fromJson(Map<String, dynamic> json) => json['seen'] as bool?;

  @override
  Map<String, dynamic>? toJson(bool state) => {'seen': state};
}
