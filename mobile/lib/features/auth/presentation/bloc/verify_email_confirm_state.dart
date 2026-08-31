import 'package:equatable/equatable.dart';

sealed class VerifyEmailConfirmState extends Equatable {
  const VerifyEmailConfirmState();

  @override
  List<Object?> get props => const [];
}

final class VerifyEmailConfirmInitial extends VerifyEmailConfirmState {
  const VerifyEmailConfirmInitial();
}

final class VerifyEmailConfirmSubmitting extends VerifyEmailConfirmState {
  const VerifyEmailConfirmSubmitting();
}

final class VerifyEmailConfirmSuccess extends VerifyEmailConfirmState {
  const VerifyEmailConfirmSuccess();
}

final class VerifyEmailConfirmFailure extends VerifyEmailConfirmState {
  const VerifyEmailConfirmFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
