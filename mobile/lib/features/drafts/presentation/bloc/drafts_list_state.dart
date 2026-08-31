import 'package:equatable/equatable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';

sealed class DraftsListState extends Equatable {
  const DraftsListState();

  @override
  List<Object?> get props => const [];
}

/// Before the `WatchDraftsUseCase` stream's first emission — Drift's
/// `.watch()` emits an initial snapshot essentially immediately (no real
/// network round trip the way e.g. `GenerationBloc`'s initial state has to
/// wait on), so this is expected to be very short-lived, but it's still a
/// real, reachable state (e.g. `DraftsPage`'s very first frame) rather
/// than something the UI can assume never renders.
final class DraftsListLoading extends DraftsListState {
  const DraftsListLoading();
}

final class DraftsListLoaded extends DraftsListState {
  const DraftsListLoaded(
    this.drafts, {
    this.resumedScene,
    this.resumedDraft,
    this.reminderResult,
  });

  final List<Draft> drafts;

  /// Non-null immediately after `DraftResumeRequested` for [resumedDraft]
  /// resolves — `DraftsPage`'s `BlocListener` reacts to this (rather than
  /// the Bloc pushing a route itself, which would need a `BuildContext` it
  /// doesn't have) by navigating to `/canvas-editor` with a
  /// `CanvasEditorPageArgs` built from this scene. A later plain
  /// `watchAll()` re-emission naturally clears this back to `null` (see
  /// `DraftsListBloc._onUpdated`, which always builds a fresh
  /// `DraftsListLoaded` with no resume fields set) — there's no separate
  /// "resume consumed" event needed to reset it.
  final CanvasScene? resumedScene;

  /// The `Draft` [resumedScene] was built from — carried alongside it so
  /// the listener can read `Draft.inputText` without re-deriving it from
  /// [drafts].
  final Draft? resumedDraft;

  /// Non-null immediately after a `DraftReminderRequested` resolves —
  /// `DraftsPage`'s listener reacts to this by showing a success/error
  /// snack bar, then it's cleared the same way [resumedScene] is (the next
  /// plain `watchAll()` re-emission builds a fresh `DraftsListLoaded` with
  /// no transient fields set; there's no separate "consumed" event).
  final Result<Failure, void>? reminderResult;

  bool get isEmpty => drafts.isEmpty;

  @override
  List<Object?> get props => [
    drafts,
    resumedScene,
    resumedDraft,
    reminderResult,
  ];
}
