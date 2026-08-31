import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/reminders/domain/repositories/reminder_repository.dart';

/// One class per use case, single `call()` method — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md. Not currently
/// called from any UI (there's no "cancel this reminder" affordance in
/// this branch's scope — see `DraftsPage`'s report), but exposed here so
/// a future branch adding one is a local change to the presentation
/// layer, not a new use case to invent alongside it.
@injectable
class CancelReminderUseCase {
  CancelReminderUseCase(this._repository);

  final ReminderRepository _repository;

  Future<Result<Failure, void>> call(String draftLocalId) =>
      _repository.cancel(draftLocalId);
}
