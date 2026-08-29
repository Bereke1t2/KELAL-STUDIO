import 'package:equatable/equatable.dart';

import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';

sealed class DraftsListEvent extends Equatable {
  const DraftsListEvent();

  @override
  List<Object?> get props => const [];
}

/// Internal — dispatched by this Bloc's own `WatchDraftsUseCase`
/// subscription (started in the constructor) every time the underlying
/// Drift query re-emits, never by presentation code directly. Named with a
/// leading underscore's spirit even though Dart events can't actually be
/// private across the `event`/`bloc` file split; see `DraftsListBloc`'s
/// doc comment.
final class DraftsListUpdated extends DraftsListEvent {
  const DraftsListUpdated(this.drafts);

  final List<Draft> drafts;

  @override
  List<Object?> get props => [drafts];
}

/// Dispatched from `DraftsPage`'s swipe-to-delete confirm action.
final class DraftDeleteRequested extends DraftsListEvent {
  const DraftDeleteRequested(this.localId);

  final String localId;

  @override
  List<Object?> get props => [localId];
}

/// Dispatched from `DraftsPage`'s tap-to-continue action — see
/// `DraftsListState.DraftsListLoaded.resumedScene`'s doc comment for how
/// the result reaches the page.
final class DraftResumeRequested extends DraftsListEvent {
  const DraftResumeRequested(this.localId);

  final String localId;

  @override
  List<Object?> get props => [localId];
}
