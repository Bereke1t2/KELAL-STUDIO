import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft_canvas_snapshot.dart';
import 'package:kelal_studio/features/drafts/domain/usecases/save_draft_usecase.dart';
import 'package:uuid/uuid.dart';

/// PRD §10.5 leaves any debounce interval for local-draft autosave unset —
/// 2 seconds is a conservative, clearly-flagged default (long enough that
/// a fast drag/resize gesture doesn't trigger a PNG-encode-and-write on
/// every frame, short enough that a user who force-quits mid-edit rarely
/// loses more than a couple of seconds of work), not an authoritative
/// product number. See mobile/.claude/skills/flutter-architecture/SKILL.md's
/// "flag, don't silently assume" rule.
const draftAutosaveDebounce = Duration(seconds: 2);

/// `idle` before any scene change has been reported this session;
/// `saving` while an autosave triggered by [DraftAutosaveCubit.sceneChanged]
/// is in flight; `saved`/`failed` once it resolves. Not surfaced in any UI
/// today (autosave is meant to be invisible — PRD §10.5 describes it as a
/// background behavior, not a user-facing action with its own feedback
/// loop) but kept as real emitted state rather than a silent side effect,
/// so this Cubit's behavior is actually testable.
enum DraftAutosaveStatus { idle, saving, saved, failed }

/// Debounces `CanvasEditorBloc` scene changes into periodic local-draft
/// autosaves — PRD §10.5. Plain `Cubit`, not a `Bloc`: there's no event
/// taxonomy or domain branching here, just "restart a timer, and on fire,
/// call a use case" — exactly the trivial-UI-local-state case
/// mobile/.claude/skills/flutter-state-management/SKILL.md reserves for
/// `Cubit` over `Bloc`.
///
/// **Calls [SaveDraftUseCase], never `DraftsRepository` directly** — see
/// mobile/CLAUDE.md's explicit "Blocs call use cases, never repositories"
/// rule, which applies to this Cubit exactly as it does to every Bloc in
/// this codebase.
@injectable
class DraftAutosaveCubit extends Cubit<DraftAutosaveStatus> {
  DraftAutosaveCubit(this._saveDraftUseCase) : super(DraftAutosaveStatus.idle);

  final SaveDraftUseCase _saveDraftUseCase;

  static const _uuid = Uuid();

  /// Generated once, here, and reused for every autosave this Cubit
  /// performs for the rest of its lifetime — so repeated autosaves within
  /// one editing session update the same `Drafts` row (matched on
  /// `Draft.localId`) instead of inserting a new draft on every debounce
  /// tick.
  final String localId = _uuid.v4();

  /// Set on the first successful autosave and reused after — a draft's
  /// `createdAt` should reflect when this editing session started, not
  /// get overwritten by every later autosave tick (`lastSavedAt` already
  /// tracks "most recent write").
  DateTime? _createdAt;

  Timer? _debounceTimer;

  /// Called on every `CanvasEditorBloc` state change the editor screen
  /// observes (see `CanvasEditorPage`'s `BlocListener` wiring). Cancels any
  /// pending debounce timer and restarts it — only the *last* scene change
  /// within [draftAutosaveDebounce] of quiescence actually gets saved.
  void sceneChanged(
    CanvasScene scene, {
    required String inputText,
    String? brandKitId,
    String? generationRecordId,
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(draftAutosaveDebounce, () {
      unawaited(
        _save(
          scene,
          inputText: inputText,
          brandKitId: brandKitId,
          generationRecordId: generationRecordId,
        ),
      );
    });
  }

  Future<void> _save(
    CanvasScene scene, {
    required String inputText,
    String? brandKitId,
    String? generationRecordId,
  }) async {
    if (isClosed) return;
    emit(DraftAutosaveStatus.saving);
    try {
      final snapshot = await DraftCanvasSnapshot.fromCanvasScene(
        scene,
        localId: localId,
      );
      final now = DateTime.now().toUtc();
      _createdAt ??= now;

      final draft = Draft(
        localId: localId,
        brandKitId: brandKitId,
        inputText: inputText,
        generationRecordId: generationRecordId,
        canvasSnapshot: snapshot,
        status: DraftStatus.draft,
        createdAt: _createdAt!,
        lastSavedAt: now,
      );

      final result = await _saveDraftUseCase(draft);
      if (isClosed) return;
      emit(
        result.isOk ? DraftAutosaveStatus.saved : DraftAutosaveStatus.failed,
      );
    }
    // The PNG-encode-and-write step inside
    // `DraftCanvasSnapshot.fromCanvasScene` is a `dart:io` file write that
    // can fail the same way Drift's own writes can (device low on storage,
    // permission revoked mid-session) — this Cubit is the only caller
    // positioned before that write happens (it runs before
    // `SaveDraftUseCase`/`DraftsRepository.save` is ever reached), so it's
    // the boundary that has to turn an unanticipated exception into
    // `DraftAutosaveStatus.failed` rather than letting it propagate.
    // Mirrors the `avoid_catches_without_on_clauses` catch-all pattern
    // used throughout `auth_repository_impl.dart`/
    // `brand_kit_repository_impl.dart`, even though this isn't literally a
    // repository method.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      if (!isClosed) emit(DraftAutosaveStatus.failed);
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
