import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/reminders/domain/entities/reminder.dart';

/// Interface only — no `flutter_local_notifications`/`permission_handler`/
/// `dio` import here. `data/repositories/reminder_repository_impl.dart` is
/// the only place that talks to `LocalNotificationScheduler`/
/// `ReminderRemoteDataSource` directly. See
/// mobile/.claude/skills/flutter-architecture/SKILL.md and
/// mobile/.claude/skills/flutter-networking-data/SKILL.md.
abstract class ReminderRepository {
  /// Schedules [reminder] — see `ReminderRepositoryImpl.schedule`'s doc
  /// comment for exactly what "schedule" does and in what order (local
  /// notification vs. the `POST /reminders` backend call).
  ///
  /// [notificationTitle]/[notificationBody] are the already-localized
  /// strings to show when the notification fires. They're passed in from
  /// the presentation layer (`DraftsListEvent.DraftReminderRequested`)
  /// rather than looked up here, since this layer has no `BuildContext`/
  /// `AppLocalizations` access and must stay pure per
  /// mobile/.claude/skills/flutter-architecture/SKILL.md's domain-purity
  /// rule — [Reminder] itself carries no display text, only the UTC
  /// schedule (PRD §6.12).
  Future<Result<Failure, void>> schedule(
    Reminder reminder, {
    required String notificationTitle,
    required String notificationBody,
  });

  /// Cancels any previously scheduled reminder for [draftLocalId] — a
  /// no-op, not an error, if none was ever scheduled (mirrors
  /// `DraftsRepository.delete`'s "no-op on an already-absent row"
  /// contract).
  Future<Result<Failure, void>> cancel(String draftLocalId);
}
