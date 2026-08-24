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

  /// Broadcasts the current sign-in state: `true` once a session exists,
  /// `false` once it doesn't. On first listen this emits the state as of
  /// right now (derived from whether a stored access token exists), then
  /// emits again on every subsequent [login]/[logout] (and, in future, any
  /// other event that ends a session, e.g. account deletion).
  ///
  /// Deliberately `Stream<bool>`, not a richer session entity/usecase — a
  /// repository-level stream is the right scope for gating navigation
  /// today (see `AppRouter`'s `redirect:`); nothing downstream needs more
  /// than the boolean yet, so this stays pure Dart and dependency-free.
  Stream<bool> watchIsAuthenticated();
}
