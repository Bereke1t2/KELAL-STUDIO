import 'package:equatable/equatable.dart';

sealed class ResetPasswordConfirmState extends Equatable {
  const ResetPasswordConfirmState();

  @override
  List<Object?> get props => const [];
}

final class ResetPasswordConfirmInitial extends ResetPasswordConfirmState {
  const ResetPasswordConfirmInitial();
}

final class ResetPasswordConfirmSubmitting extends ResetPasswordConfirmState {
  const ResetPasswordConfirmSubmitting();
}

final class ResetPasswordConfirmSuccess extends ResetPasswordConfirmState {
  const ResetPasswordConfirmSuccess();
}

final class ResetPasswordConfirmFailure extends ResetPasswordConfirmState {
  const ResetPasswordConfirmFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
