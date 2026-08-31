import 'package:kelal_studio/core/network/fake_backend_support.dart'
    show ApiException;

import 'package:kelal_studio/features/reminders/data/datasources/fake_reminder_remote_data_source.dart'
    show FakeReminderRemoteDataSource;

import 'package:kelal_studio/features/reminders/data/datasources/reminder_api.dart'
    show ReminderApi;

/// Implemented by both the [ReminderApi]-backed real data source and
/// [FakeReminderRemoteDataSource]. The repository depends only on this
/// interface — see mobile/.claude/skills/flutter-networking-data/SKILL.md
/// for the mock/real swap mechanism (`reminder_datasource_module.dart`).
///
/// Throws [ApiException] (never a raw `DioException`) on failure — mapping
/// happens once, at the edge, via `core/network/api_exception_mapper.dart`.
abstract class ReminderRemoteDataSource {
  Future<void> createReminder({
    required String draftLocalId,
    required DateTime scheduledAtUtc,
  });
}
