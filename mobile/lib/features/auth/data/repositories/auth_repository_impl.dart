import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/core/storage/secure_token_storage.dart';
import 'package:kelal_studio/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:kelal_studio/features/auth/domain/entities/auth_session.dart';
import 'package:kelal_studio/features/auth/domain/repositories/auth_repository.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._tokenStorage) {
    // `onListen` fires on the 0-listener -> 1-listener transition, which is
    // exactly the "seed on first listen" behavior this stream needs: the
    // very first subscriber (AppRouter's GoRouterRefreshStream) triggers a
    // read of the current token state; anyone subscribing after that just
    // gets it (and every subsequent login/logout emission) for free.
    _authStateController = StreamController<bool>.broadcast(
      onListen: _emitCurrentAuthState,
    );
  }

  final AuthRemoteDataSource _remote;
  final SecureTokenStorage _tokenStorage;
  late final StreamController<bool> _authStateController;

  @override
  Stream<bool> watchIsAuthenticated() => _authStateController.stream;

  Future<void> _emitCurrentAuthState() async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (!_authStateController.isClosed) {
      _authStateController.add(accessToken != null);
    }
  }

  /// Shared by [logout] today; a future account-deletion flow can call this
  /// too so both paths push the same `false` session-ended signal without
  /// duplicating the "is the controller still open" guard.
  void _emitLoggedOut() {
    if (!_authStateController.isClosed) {
      _authStateController.add(false);
    }
  }

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
      if (!_authStateController.isClosed) {
        _authStateController.add(true);
      }
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
  Future<void> logout() async {
    await _tokenStorage.clear();
    _emitLoggedOut();
  }

  @override
  Future<Result<Failure, void>> deleteAccount() async {
    try {
      // Mocking the delete account backend call for now since no remote
      // method exists yet. Clears local token as a side effect (the user
      // is "deleted" and thus logged out locally, which also notifies the
      // router's auth-gate via [logout]'s `_emitLoggedOut()` call — merge
      // note: main's version of [logout] didn't call `_emitLoggedOut()`,
      // which would have silently broken auth-gate redirects on
      // logout/delete; restored here).
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
