import 'package:equatable/equatable.dart';

sealed class AccountState extends Equatable {
  const AccountState();

  @override
  List<Object?> get props => const [];
}

final class AccountInitial extends AccountState {
  const AccountInitial();
}

final class AccountDeleting extends AccountState {
  const AccountDeleting();
}

final class AccountDeleted extends AccountState {
  const AccountDeleted();
}

final class AccountDeleteError extends AccountState {
  const AccountDeleteError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
