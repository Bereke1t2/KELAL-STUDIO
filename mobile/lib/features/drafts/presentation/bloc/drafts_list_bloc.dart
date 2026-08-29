import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';
import 'package:kelal_studio/features/drafts/domain/usecases/delete_draft_usecase.dart';
import 'package:kelal_studio/features/drafts/domain/usecases/resume_draft_usecase.dart';
import 'package:kelal_studio/features/drafts/domain/usecases/watch_drafts_usecase.dart';
import 'package:kelal_studio/features/drafts/presentation/bloc/drafts_list_event.dart';
import 'package:kelal_studio/features/drafts/presentation/bloc/drafts_list_state.dart';

/// Backs `DraftsPage` — subscribes to `WatchDraftsUseCase`'s reactive
/// stream directly in the constructor (no other Bloc in this codebase
/// subscribes to an ongoing stream today — `AuthRepositoryImpl`'s
/// `watchIsAuthenticated`/`watchEmailVerified` streams are consumed by
/// `GoRouterRefreshStream`/`EmailVerificationGate` instead, neither of
/// which is a Bloc — so this is a plain `StreamSubscription` started here
/// and forwarded into this Bloc's own event stream via `add`, rather than
/// an established in-repo pattern being reused), converting each
/// `List<Draft>` emission into a [DraftsListUpdated] event so it still
/// flows through the same `on<Event>` handling every other state change
/// here does.
@injectable
class DraftsListBloc extends Bloc<DraftsListEvent, DraftsListState> {
  DraftsListBloc(
    this._watchDraftsUseCase,
    this._deleteDraftUseCase,
    this._resumeDraftUseCase,
  ) : super(const DraftsListLoading()) {
    on<DraftsListUpdated>(_onUpdated, transformer: restartable());
    // Deletions are user-initiated, destructive, one-at-a-time taps (a
    // swipe-to-delete confirm per card) — `sequential()` so a fast double
    // swipe on two different cards deletes both, in the order tapped,
    // rather than one dropping (`droppable()`) or racing
    // (`concurrent()`/implicit default; see
    // mobile/.claude/skills/flutter-state-management/SKILL.md's
    // transformer table). The list itself doesn't need to be updated by
    // this handler — `watchAll()`'s reactive query already re-emits (and
    // reaches this Bloc via [DraftsListUpdated]) the moment the row is
    // actually gone.
    on<DraftDeleteRequested>(_onDeleteRequested, transformer: sequential());
    // `droppable()`: resuming a draft navigates away from this screen
    // entirely once it lands (see `DraftsListLoaded.resumedScene`'s doc
    // comment), so a second tap landing while the PNG redecode from the
    // first is still in flight should be ignored, not queued
    // (`sequential()`) or allowed to race it (`concurrent()`).
    on<DraftResumeRequested>(_onResumeRequested, transformer: droppable());

    _subscription = _watchDraftsUseCase().listen(
      (drafts) => add(DraftsListUpdated(drafts)),
    );
  }

  final WatchDraftsUseCase _watchDraftsUseCase;
  final DeleteDraftUseCase _deleteDraftUseCase;
  final ResumeDraftUseCase _resumeDraftUseCase;
  late final StreamSubscription<List<Draft>> _subscription;

  void _onUpdated(DraftsListUpdated event, Emitter<DraftsListState> emit) {
    emit(DraftsListLoaded(event.drafts));
  }

  Future<void> _onDeleteRequested(
    DraftDeleteRequested event,
    Emitter<DraftsListState> emit,
  ) async {
    // Result intentionally not branched on here: a delete failure (see
    // `DraftRepositoryImpl.delete`'s `CacheFailure`) leaves the row in
    // place, which `watchAll()`'s next emission already reflects on its
    // own — there's no separate error state for this Bloc to track
    // without duplicating that reactive source of truth.
    await _deleteDraftUseCase(event.localId);
  }

  Future<void> _onResumeRequested(
    DraftResumeRequested event,
    Emitter<DraftsListState> emit,
  ) async {
    final current = state;
    if (current is! DraftsListLoaded) return;
    Draft? draft;
    for (final candidate in current.drafts) {
      if (candidate.localId == event.localId) {
        draft = candidate;
        break;
      }
    }
    if (draft == null) return;

    final scene = await _resumeDraftUseCase(draft);
    emit(
      DraftsListLoaded(
        current.drafts,
        resumedScene: scene,
        resumedDraft: draft,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
