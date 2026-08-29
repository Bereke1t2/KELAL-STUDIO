import 'package:equatable/equatable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_result.dart';

sealed class GenerationState extends Equatable {
  const GenerationState();

  @override
  List<Object?> get props => const [];
}

final class GenerationInitial extends GenerationState {
  const GenerationInitial();
}

final class GenerationInProgress extends GenerationState {
  const GenerationInProgress();
}

final class GenerationSuccess extends GenerationState {
  const GenerationSuccess(this.result);
  final GenerationResult result;

  @override
  List<Object?> get props => [result];
}

/// Carries the full [ApiFailure], not just a plain message string (unlike
/// `QuotaLoadFailure`/`BrandKitSaveFailure`) — the widget layer needs
/// [ApiFailure.type] to decide between `showQuotaExceededDialog`
/// ([ApiErrorType.quotaExceeded]) and an `AppLocalizations`-mapped inline
/// message for every other type (see `ComposerPage`'s error-mapping
/// switch), plus [ApiFailure.resetsAt]/`moderationReason` for those two
/// cases respectively — a bare `String` can't carry either.
final class GenerationFailure extends GenerationState {
  const GenerationFailure(this.failure);
  final ApiFailure failure;

  // [ApiFailure] itself has no `==`/`hashCode` override (it's a plain
  // class, not `Equatable`) — comparing `[failure]` directly would fall
  // back to identity equality, so two structurally-identical but
  // separately-constructed `ApiFailure`s (e.g. one built fresh by
  // `GenerationBloc`, one built fresh in a test's `expect`) would
  // wrongly compare unequal. Destructuring into `failure`'s constituent
  // fields here compares by value instead, the same problem
  // `LoginFailure`/`BrandKitSaveFailure` sidestep by storing a plain
  // `String message` rather than the whole `ApiFailure`.
  @override
  List<Object?> get props => [
    failure.type,
    failure.message,
    failure.resetsAt,
    failure.moderationReason,
  ];
}
