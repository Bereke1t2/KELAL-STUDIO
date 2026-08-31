import 'package:equatable/equatable.dart';

sealed class ResendVerificationEvent extends Equatable {
  const ResendVerificationEvent();
}

final class ResendVerificationRequested extends ResendVerificationEvent {
  const ResendVerificationRequested({required this.email});
  final String email;

  @override
  List<Object?> get props => [email];
}
