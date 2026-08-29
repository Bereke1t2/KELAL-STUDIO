import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/core/storage/secure_token_storage.dart';
import 'package:kelal_studio/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:kelal_studio/features/auth/domain/entities/auth_session.dart';
import 'package:kelal_studio/features/auth/domain/repositories/auth_repository.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._tokenStorage);

  final AuthRemoteDataSource _remote;
  final SecureTokenStorage _tokenStorage;

  @override
  Future<Result<Failure, AuthSession>> login({
    required String email,
    required String password,
  }) async {
    try {
      final tokens = await _remote.login(email: email, password: password);
      await _tokenStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return const Result.ok(AuthSession(isAuthenticated: true));
    } on ApiException catch (e) {
      return Result.err(e.failure);
    }
    // Deliberate catch-all: this is the repository boundary — per
    // flutter-architecture, nothing above this layer may throw, so any
    // exception type we didn't anticipate still needs to become a
    // Result.err rather than propagate.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        UnexpectedFailure('Something went wrong. Please try again.'),
      );
    }
  }

  @override
  Future<void> logout() => _tokenStorage.clear();

  @override
  Future<Result<Failure, void>> deleteAccount() async {
    try {
      // Mocking the delete account backend call for now since no remote
      // method exists yet. Clears local token as a side effect (the user
      // is "deleted" and thus logged out locally).
      await logout();
      return const Result.ok(null);
    }
    // Deliberate catch-all: this is the repository boundary — per
    // flutter-architecture, nothing above this layer may throw, so any
    // exception type we didn't anticipate still needs to become a
    // Result.err rather than propagate.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        UnexpectedFailure('Something went wrong. Please try again.'),
      );
    }
  }
}
