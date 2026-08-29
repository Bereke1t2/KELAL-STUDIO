import 'package:equatable/equatable.dart';
import 'package:kelal_studio/features/export/domain/entities/export_failure.dart';

/// Deliberately a single sealed state (not two independent
/// save/share-status fields on one state class): `ExportGallerySaveRequested`
/// and `ExportShareRequested` are two separate, user-tap-triggered actions
/// on the same screen that are never expected to run genuinely concurrently
/// in normal use (a user taps one button, waits for the outcome, then maybe
/// taps the other) — modeling them as one linear state sequence keeps
/// `ExportPage`'s `BlocConsumer` simple (one `switch`, not a compound
/// object with two independently-tracked booleans). If a later change
/// wants both actions' progress visible simultaneously, that's the point
/// to split this into a compound state — flagged here as a deliberate
/// simplification, not an oversight.
sealed class ExportState extends Equatable {
  const ExportState();

  @override
  List<Object?> get props => const [];
}

final class ExportInitial extends ExportState {
  const ExportInitial();
}

final class ExportGallerySaveInProgress extends ExportState {
  const ExportGallerySaveInProgress();
}

final class ExportGallerySaveSuccess extends ExportState {
  const ExportGallerySaveSuccess();
}

final class ExportGallerySaveFailure extends ExportState {
  const ExportGallerySaveFailure(this.type, this.message);

  final ExportFailureType type;
  final String message;

  @override
  List<Object?> get props => [type, message];
}

final class ExportShareInProgress extends ExportState {
  const ExportShareInProgress();
}

/// Reached once the Share Sheet has been successfully invoked — not shown
/// with its own confirmation snack bar by `ExportPage` (the OS-level sheet
/// appearing/dismissing is itself the user-visible confirmation); kept as
/// a distinct state purely so tests can assert the bloc actually reached a
/// terminal success outcome, not just that share was invoked.
final class ExportShareSuccess extends ExportState {
  const ExportShareSuccess();
}

final class ExportShareFailure extends ExportState {
  const ExportShareFailure(this.type, this.message);

  final ExportFailureType type;
  final String message;

  @override
  List<Object?> get props => [type, message];
}
