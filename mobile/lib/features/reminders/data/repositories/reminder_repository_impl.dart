import 'dart:async';

import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/core/notifications/local_notification_scheduler.dart';
import 'package:kelal_studio/features/reminders/data/datasources/reminder_remote_data_source.dart';
import 'package:kelal_studio/features/reminders/domain/entities/reminder.dart';
import 'package:kelal_studio/features/reminders/domain/entities/reminder_failure.dart';
import 'package:kelal_studio/features/reminders/domain/repositories/reminder_repository.dart';

/// Combines on-device scheduling (`LocalNotificationScheduler`) with a
/// best-effort `POST /reminders` backend call.
///
/// **Ordering decision (flagged, not silently made)**: the local
/// notification is the source of truth for whether a reminder actually
/// fires — it's scheduled first, and only its outcome is returned to the
/// caller. The backend call is fire-and-forget after that: nothing in the
/// PRD says what the backend record is *for* (no read endpoint exists in
/// `api_contract/openapi.yaml`, only the `POST`), so it reads as
/// server-side analytics/audit rather than something the app depends on to
/// make the reminder work. A backend failure (network down, unauthorized,
/// etc.) must never undo an otherwise-successfully-scheduled local
/// notification, so its result is swallowed rather than surfaced.
@LazySingleton(as: ReminderRepository)
class ReminderRepositoryImpl implements ReminderRepository {
  ReminderRepositoryImpl(this._scheduler, this._remote);

  final LocalNotificationScheduler _scheduler;
  final ReminderRemoteDataSource _remote;

  @override
  Future<Result<Failure, void>> schedule(
    Reminder reminder, {
    required String notificationTitle,
    required String notificationBody,
  }) async {
    final granted = await _scheduler.requestPermission();
    if (!granted) {
      return const Result.err(
        ReminderPermissionDeniedFailure(
          'Notifications are turned off for this app.',
        ),
      );
    }

    try {
      await _scheduler.schedule(
        draftLocalId: reminder.draftLocalId,
        scheduledAtUtc: reminder.scheduledAtUtc,
        notificationId: reminder.notificationId,
        title: notificationTitle,
        body: notificationBody,
      );
    }
    // Deliberate catch-all at this boundary — see
    // `QuotaRepositoryImpl.getQuota`'s matching comment for why. A
    // scheduling failure here is a real, user-visible outcome (the
    // reminder was NOT set), not something to swallow the way the
    // best-effort backend call below is.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        UnexpectedFailure('Could not set that reminder. Please try again.'),
      );
    }

    // Best-effort only — see class doc comment. Never awaited into the
    // caller's result and never lets an exception escape this method.
    unawaited(_notifyBackend(reminder));

    return const Result.ok(null);
  }

  Future<void> _notifyBackend(Reminder reminder) async {
    try {
      await _remote.createReminder(
        draftLocalId: reminder.draftLocalId,
        scheduledAtUtc: reminder.scheduledAtUtc,
      );
    } on ApiException {
      // Swallowed — see class doc comment.
    }
    // Deliberate catch-all: this is a fire-and-forget best-effort call, not
    // a boundary that reports failures to a caller — an unanticipated
    // exception type must be swallowed here exactly like `ApiException` is
    // above, never propagate out of `unawaited(_notifyBackend(...))`.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      // Swallowed — see class doc comment.
    }
  }

  @override
  Future<Result<Failure, void>> cancel(String draftLocalId) async {
    try {
      await _scheduler.cancel(Reminder.notificationIdFor(draftLocalId));
      return const Result.ok(null);
    }
    // Same reasoning as `schedule`'s catch-all above: this is a real,
    // user-visible boundary (`Result`-wrapped per the interface), not the
    // best-effort backend call — an unanticipated plugin exception must
    // become a `Result.err`, not propagate.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        UnexpectedFailure('Could not cancel that reminder. Please try again.'),
      );
    }
  }
}
