import 'package:equatable/equatable.dart';

sealed class QuotaEvent extends Equatable {
  const QuotaEvent();
}

/// Fetches the current quota. Dispatched once on `QuotaStatusBadge` mount,
/// and safe to dispatch again for a manual/automatic refresh — see
/// `QuotaBloc`'s doc comment for why repeated dispatch is handled with
/// `restartable()` rather than `droppable()`.
final class QuotaRequested extends QuotaEvent {
  const QuotaRequested();

  @override
  List<Object?> get props => const [];
}
