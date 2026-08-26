import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/auth/domain/entities/auth_session.dart';

/// Interface only — no `dio`, no `retrofit` import here. The concrete
/// implementation (`data/repositories/auth_repository_impl.dart`) picks a
/// real or fake data source at construction time; nothing above this
/// interface knows or cares which. See
/// mobile/.claude/skills/flutter-networking-data/SKILL.md.
abstract class AuthRepository {
  Future<Result<Failure, AuthSession>> login({
    required String email,
    required String password,
  });

  Future<Result<Failure, void>> deleteAccount();
  Future<void> logout();
}
