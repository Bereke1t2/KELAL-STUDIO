import 'package:kelal_studio/core/error/result.dart';

/// Reminder-specific failure: the one case a generic [UnexpectedFailure]/
/// [CacheFailure] doesn't distinguish and that `DraftsPage` needs to show
/// different copy for (a "grant notification permission in Settings" nudge
/// vs. a plain "something went wrong" retry message) — mirrors why
/// `features/export/domain/entities/export_failure.dart` exists as its own
/// small enum rather than everything collapsing into `UnexpectedFailure`.
class ReminderPermissionDeniedFailure extends Failure {
  const ReminderPermissionDeniedFailure(super.message);
}
