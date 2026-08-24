import 'package:equatable/equatable.dart';

/// Pure-Dart domain entity — no Flutter, no json, no dio imports here (see
/// mobile/.claude/skills/flutter-architecture/SKILL.md's domain-purity
/// rule). [data/models] DTOs map onto this; this is what use cases and
/// presentation code actually depend on.
class AuthSession extends Equatable {
  const AuthSession({
    required this.isAuthenticated,
    required this.emailVerified,
  });

  final bool isAuthenticated;

  /// Mirrors `AuthTokens.email_verified` (see
  /// mobile/api_contract/openapi.yaml) — drives the compose-gate
  /// (`EmailVerificationGate`, PRD §6.1: "Email verification gates content
  /// generation"). Meaningless when [isAuthenticated] is false.
  final bool emailVerified;

  @override
  List<Object?> get props => [isAuthenticated, emailVerified];
}
