import 'package:equatable/equatable.dart';

sealed class ResendVerificationState extends Equatable {
  const ResendVerificationState();

  @override
  List<Object?> get props => const [];
}

final class ResendVerificationIdle extends ResendVerificationState {
  const ResendVerificationIdle();
}

final class ResendVerificationSending extends ResendVerificationState {
  const ResendVerificationSending();
}

/// Reached on *any* non-network success — per the same anti-enumeration
/// contract `ResetPasswordRequestSuccess` documents, this state is reached
/// whether or not the email belongs to a real, unverified account. There
/// is deliberately no state/branch that would let the UI distinguish the
/// two.
final class ResendVerificationSent extends ResendVerificationState {
  const ResendVerificationSent();
}

/// Reached only for a genuine transport/unexpected failure — never for
/// "email not found" or "already verified," neither of which is a
/// distinguishable outcome by contract.
final class ResendVerificationFailure extends ResendVerificationState {
  const ResendVerificationFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
