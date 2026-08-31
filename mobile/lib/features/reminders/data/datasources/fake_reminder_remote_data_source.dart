import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/reminders/data/datasources/reminder_remote_data_source.dart';

/// Professional fake: realistic latency (via [FakeBackendSupport.latency]),
/// no persisted state — `POST /reminders` is fire-and-forget from the
/// client's point of view (the `201` response has no body, see
/// `reminder_api.dart`), and the reminder actually firing is handled
/// entirely on-device by `LocalNotificationScheduler`, not by this backend
/// call. This fake exists only so the repository's "best-effort backend
/// notify" step (see `ReminderRepositoryImpl`) has something to call
/// against `Env.useMockApi == true` — see
/// mobile/.claude/skills/flutter-networking-data/SKILL.md.
class FakeReminderRemoteDataSource implements ReminderRemoteDataSource {
  @override
  Future<void> createReminder({
    required String draftLocalId,
    required DateTime scheduledAtUtc,
  }) async {
    await FakeBackendSupport.latency();
  }
}
