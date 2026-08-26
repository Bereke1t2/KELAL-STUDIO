import 'package:equatable/equatable.dart';

sealed class AccountEvent extends Equatable {
  const AccountEvent();
}

final class AccountDeleteRequested extends AccountEvent {
  const AccountDeleteRequested();

  @override
  List<Object?> get props => const [];
}
