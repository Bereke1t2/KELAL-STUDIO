import 'package:equatable/equatable.dart';
import 'package:kelal_studio/core/error/result.dart';

sealed class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object?> get props => const [];
}

final class LoginInitial extends LoginState {
  const LoginInitial();
}

final class LoginSubmitting extends LoginState {
  const LoginSubmitting();
}

final class LoginSuccess extends LoginState {
  const LoginSuccess();
}

/// [errorType] drives which message the UI actually shows: known
/// client-localizable cases (e.g. [ApiErrorType.validationError] here means
/// "invalid credentials") are resolved through `AppLocalizations` at the
/// widget layer rather than trusting [message] to already be in the user's
/// chosen app-interface language. [message] is kept as the fallback for
/// error types the PRD says the *backend* already localizes to the input
/// language (e.g. moderation refusals) — see
/// mobile/.claude/skills/flutter-networking-data/SKILL.md and PRD §6.4.
final class LoginFailure extends LoginState {
  const LoginFailure(this.message, this.errorType);
  final String message;
  final ApiErrorType errorType;

  @override
  List<Object?> get props => [message, errorType];
}
