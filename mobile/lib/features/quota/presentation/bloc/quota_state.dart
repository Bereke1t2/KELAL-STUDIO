import 'package:equatable/equatable.dart';

import 'package:kelal_studio/features/quota/domain/entities/quota.dart';

sealed class QuotaState extends Equatable {
  const QuotaState();

  @override
  List<Object?> get props => const [];
}

final class QuotaInitial extends QuotaState {
  const QuotaInitial();
}

final class QuotaLoadInProgress extends QuotaState {
  const QuotaLoadInProgress();
}

final class QuotaLoaded extends QuotaState {
  const QuotaLoaded(this.quota);
  final Quota quota;

  @override
  List<Object?> get props => [quota];
}

final class QuotaLoadFailure extends QuotaState {
  const QuotaLoadFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
