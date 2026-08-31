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

/// Dispatched from `DraftsPage`'s "Remind me" card action, after the user
/// has picked a date/time via `pickReminderDateTimeUtc` — PRD §6.12/§8.5.
/// [notificationTitle]/[notificationBody] are already-localized (picked in
/// `DraftsPage`, which has `AppLocalizations` access) — see
/// `ReminderRepository.schedule`'s doc comment for why they travel this far
/// as plain strings rather than being resolved deeper in the stack.
final class DraftReminderRequested extends DraftsListEvent {
  const DraftReminderRequested({
    required this.localId,
    required this.scheduledAtUtc,
    required this.notificationTitle,
    required this.notificationBody,
  });

  final String localId;
  final DateTime scheduledAtUtc;
  final String notificationTitle;
  final String notificationBody;

  @override
  List<Object?> get props => [
    localId,
    scheduledAtUtc,
    notificationTitle,
    notificationBody,
  ];
}
