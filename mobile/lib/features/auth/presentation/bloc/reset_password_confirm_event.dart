import 'package:equatable/equatable.dart';

sealed class ResetPasswordConfirmEvent extends Equatable {
  const ResetPasswordConfirmEvent();
}

final class ResetPasswordConfirmSubmitted extends ResetPasswordConfirmEvent {
  const ResetPasswordConfirmSubmitted({
    required this.token,
    required this.newPassword,
  });
  final String token;
  final String newPassword;

  @override
  List<Object?> get props => [token, newPassword];
}
