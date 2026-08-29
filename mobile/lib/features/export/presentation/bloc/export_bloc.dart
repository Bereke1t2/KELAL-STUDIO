import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/render_engine/render_engine.dart';
import 'package:kelal_studio/features/export/domain/usecases/save_export_to_gallery_usecase.dart';
import 'package:kelal_studio/features/export/domain/usecases/share_export_usecase.dart';
import 'package:kelal_studio/features/export/presentation/bloc/export_event.dart';
import 'package:kelal_studio/features/export/presentation/bloc/export_state.dart';

/// Both handlers use `droppable()`, deliberately — PRD §6.11's gallery
/// save and OS Share Sheet invocation are exactly the
/// `mobile/.claude/skills/flutter-state-management/SKILL.md` transformer
/// table's "Submit-style actions" row, which names **export** explicitly
/// alongside login/generate as a case where a double-tap must not fire the
/// action twice: a dropped second `ExportGallerySaveRequested` prevents two
/// concurrent gallery writes (in the worst case, two visible/duplicate
/// saved images or two overlapping permission-request dialogs); a dropped
/// second `ExportShareRequested` prevents stacking two native Share Sheets.
/// Each event type gets its own transformer pipe (`on<T>` registers
/// independently), so a save and a share can still both be in flight at
/// once if a user taps both buttons in quick succession — see
/// `ExportState`'s doc comment for why that's an accepted simplification
/// rather than a guarded-against race.
@injectable
class ExportBloc extends Bloc<ExportEvent, ExportState> {
  ExportBloc(this._saveExportToGalleryUseCase, this._shareExportUseCase)
    : super(const ExportInitial()) {
    on<ExportGallerySaveRequested>(
      _onGallerySaveRequested,
      transformer: droppable(),
    );
    on<ExportShareRequested>(_onShareRequested, transformer: droppable());
  }

  final SaveExportToGalleryUseCase _saveExportToGalleryUseCase;
  final ShareExportUseCase _shareExportUseCase;

  Future<void> _onGallerySaveRequested(
    ExportGallerySaveRequested event,
    Emitter<ExportState> emit,
  ) async {
    emit(const ExportGallerySaveInProgress());
    // RenderEngine.exportPng is the single paint path shared with the live
    // editor (core/render_engine's whole reason to exist) — never a second,
    // export-specific rendering routine. See its own doc comment.
    final pngBytes = await RenderEngine.exportPng(event.scene);
    final result = await _saveExportToGalleryUseCase(pngBytes);
    emit(
      result.when(
        ok: (_) => const ExportGallerySaveSuccess(),
        err: (failure) =>
            ExportGallerySaveFailure(failure.type, failure.message),
      ),
    );
  }

  Future<void> _onShareRequested(
    ExportShareRequested event,
    Emitter<ExportState> emit,
  ) async {
    emit(const ExportShareInProgress());
    final pngBytes = await RenderEngine.exportPng(event.scene);
    final result = await _shareExportUseCase(
      pngBytes: pngBytes,
      text: event.captionText,
    );
    emit(
      result.when(
        ok: (_) => const ExportShareSuccess(),
        err: (failure) => ExportShareFailure(failure.type, failure.message),
      ),
    );
  }
}
