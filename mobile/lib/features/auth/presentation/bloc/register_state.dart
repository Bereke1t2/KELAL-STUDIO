import 'package:equatable/equatable.dart';
import 'package:kelal_studio/core/error/result.dart';

sealed class RegisterState extends Equatable {
  const RegisterState();

  @override
  List<Object?> get props => const [];
}

final class RegisterInitial extends RegisterState {
  const RegisterInitial();
}

final class RegisterSubmitting extends RegisterState {
  const RegisterSubmitting();
}

final class RegisterSuccess extends RegisterState {
  const RegisterSuccess();
}

/// Unlike `LoginFailure`, register errors (e.g. "email already
/// registered") are legitimately informative and not subject to the
/// anti-enumeration constraint (that only applies to
/// `/auth/password-reset/request` — PRD §6.1) — so [message] is shown
/// directly, no client-side override.
final class RegisterFailure extends RegisterState {
  const RegisterFailure(this.message, this.errorType);
  final String message;
  final ApiErrorType errorType;

  @override
  List<Object?> get props => [message, errorType];
}
