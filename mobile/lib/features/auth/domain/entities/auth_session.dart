import 'package:equatable/equatable.dart';

/// Pure-Dart domain entity — no Flutter, no json, no dio imports here (see
/// mobile/.claude/skills/flutter-architecture/SKILL.md's domain-purity
/// rule). [data/models] DTOs map onto this; this is what use cases and
/// presentation code actually depend on.
class AuthSession extends Equatable {
  const AuthSession({required this.isAuthenticated});

  final bool isAuthenticated;

  @override
  List<Object?> get props => [isAuthenticated];
}
