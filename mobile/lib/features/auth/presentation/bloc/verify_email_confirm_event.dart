import 'package:equatable/equatable.dart';

sealed class VerifyEmailConfirmEvent extends Equatable {
  const VerifyEmailConfirmEvent();
}

final class VerifyEmailConfirmSubmitted extends VerifyEmailConfirmEvent {
  const VerifyEmailConfirmSubmitted({required this.token});
  final String token;

  @override
  List<Object?> get props => [token];
}
