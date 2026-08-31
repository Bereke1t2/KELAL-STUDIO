import 'package:equatable/equatable.dart';

sealed class ResetPasswordRequestEvent extends Equatable {
  const ResetPasswordRequestEvent();
}

final class ResetPasswordRequestSubmitted extends ResetPasswordRequestEvent {
  const ResetPasswordRequestSubmitted({required this.email});
  final String email;

  @override
  List<Object?> get props => [email];
}
