import 'package:equatable/equatable.dart';

sealed class ResetPasswordRequestState extends Equatable {
  const ResetPasswordRequestState();

  @override
  List<Object?> get props => const [];
}

final class ResetPasswordRequestInitial extends ResetPasswordRequestState {
  const ResetPasswordRequestInitial();
}

final class ResetPasswordRequestSubmitting extends ResetPasswordRequestState {
  const ResetPasswordRequestSubmitting();
}

/// Reached on *any* non-network success — per PRD §6.1 anti-enumeration,
/// this state (and the identical confirmation UI it drives) is reached
/// whether or not the submitted email belongs to a real account. There is
/// deliberately no state/branch that would let the UI distinguish the two.
final class ResetPasswordRequestSuccess extends ResetPasswordRequestState {
  const ResetPasswordRequestSuccess();
}

/// Reached only for a genuine transport/unexpected failure (e.g. no
/// network) — never for "email not found," which is not a distinguishable
/// outcome by contract.
final class ResetPasswordRequestFailure extends ResetPasswordRequestState {
  const ResetPasswordRequestFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
