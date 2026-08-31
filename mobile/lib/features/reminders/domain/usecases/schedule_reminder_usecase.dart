import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/reminders/domain/entities/reminder.dart';
import 'package:kelal_studio/features/reminders/domain/repositories/reminder_repository.dart';

/// One class per use case, single `call()` method — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md.
@injectable
class ScheduleReminderUseCase {
  ScheduleReminderUseCase(this._repository);

  final ReminderRepository _repository;

  Future<Result<Failure, void>> call(
    Reminder reminder, {
    required String notificationTitle,
    required String notificationBody,
  }) => _repository.schedule(
    reminder,
    notificationTitle: notificationTitle,
    notificationBody: notificationBody,
  );
}
