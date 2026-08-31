import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/core/storage/secure_token_storage.dart';
import 'package:kelal_studio/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:kelal_studio/features/auth/data/models/auth_tokens_dto.dart';
import 'package:kelal_studio/features/auth/domain/entities/auth_session.dart';
import 'package:kelal_studio/features/auth/domain/entities/registration_outcome.dart';
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
    // Same seed-on-first-listen shape as [_authStateController], for the
    // same reason (see [EmailVerificationGate], the first real subscriber).
    _emailVerifiedController = StreamController<bool>.broadcast(
      onListen: _emitCurrentEmailVerified,
    );
  }

  final AuthRemoteDataSource _remote;
  final SecureTokenStorage _tokenStorage;
  late final StreamController<bool> _authStateController;
  late final StreamController<bool> _emailVerifiedController;

  @override
  Stream<bool> watchIsAuthenticated() => _authStateController.stream;

  @override
  Stream<bool> watchEmailVerified() => _emailVerifiedController.stream;

  Future<void> _emitCurrentAuthState() async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (!_authStateController.isClosed) {
      _authStateController.add(accessToken != null);
    }
  }

  Future<void> _emitCurrentEmailVerified() async {
    final verified = await _tokenStorage.readEmailVerified();
    if (!_emailVerifiedController.isClosed) {
      _emailVerifiedController.add(verified);
    }
  }

  /// Shared by [logout] and [deleteAccount] (after its API call succeeds)
  /// so both paths push the same "session ended" signal without
  /// duplicating the "is the controller still open" guard.
  void _emitLoggedOut() {
    if (!_authStateController.isClosed) {
      _authStateController.add(false);
    }
    if (!_emailVerifiedController.isClosed) {
      _emailVerifiedController.add(false);
    }
  }

  Future<AuthSession> _persistAndEmit(AuthTokensDto tokens) async {
    await _tokenStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    await _tokenStorage.saveEmailVerified(verified: tokens.emailVerified);
    if (!_authStateController.isClosed) {
      _authStateController.add(true);
    }
    if (!_emailVerifiedController.isClosed) {
      _emailVerifiedController.add(tokens.emailVerified);
    }
    return AuthSession(
      isAuthenticated: true,
      emailVerified: tokens.emailVerified,
    );
  }

  @override
  Future<Result<Failure, AuthSession>> login({
    required String email,
    required String password,
  }) async {
    try {
      final tokens = await _remote.login(email: email, password: password);
      return Result.ok(await _persistAndEmit(tokens));
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
  Future<Result<Failure, RegistrationOutcome>> register({
    required String email,
    required String password,
  }) async {
    try {
      // Deliberately does NOT call _persistAndEmit — registration no
      // longer establishes a session (see RegistrationOutcome's doc
      // comment). No tokens exist yet to persist, and _authStateController/
      // _emailVerifiedController are left exactly as they were.
      final result = await _remote.register(email: email, password: password);
      return Result.ok(
        RegistrationOutcome(
          userId: result.userId,
          verificationSent: result.verificationSent,
        ),
      );
    } on ApiException catch (e) {
      return Result.err(e.failure);
    }
    // Deliberate catch-all: repository boundary, same reasoning as login()
    // above — any unanticipated exception still becomes a Result.err.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        UnexpectedFailure('Something went wrong. Please try again.'),
      );
    }
  }

  @override
  Future<Result<Failure, bool>> verifyEmail({required String token}) async {
    try {
      final verified = await _remote.verifyEmail(token: token);
      return Result.ok(verified);
    } on ApiException catch (e) {
      return Result.err(e.failure);
    }
    // Deliberate catch-all: repository boundary, same reasoning as login()
    // above — any unanticipated exception still becomes a Result.err.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        UnexpectedFailure('Something went wrong. Please try again.'),
      );
    }
  }

  @override
  Future<Result<Failure, void>> resendVerificationEmail({
    required String email,
  }) async {
    try {
      await _remote.resendVerification(email: email);
      return const Result.ok(null);
    } on ApiException catch (e) {
      // Only reached for a genuine transport failure — same anti-
      // enumeration contract as requestPasswordReset above.
      return Result.err(e.failure);
    }
    // Deliberate catch-all: repository boundary, same reasoning as login()
    // above — any unanticipated exception still becomes a Result.err.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        UnexpectedFailure('Something went wrong. Please try again.'),
      );
    }
  }

  @override
  Future<Result<Failure, void>> requestPasswordReset({
    required String email,
  }) async {
    try {
      await _remote.requestPasswordReset(email: email);
      return const Result.ok(null);
    } on ApiException catch (e) {
      // Only reached for a genuine transport failure — the anti-
      // enumeration contract means this never distinguishes "email
      // exists" from "email doesn't exist" in any branch here.
      return Result.err(e.failure);
    }
    // Deliberate catch-all: repository boundary, same reasoning as login()
    // above — any unanticipated exception still becomes a Result.err.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        UnexpectedFailure('Something went wrong. Please try again.'),
      );
    }
  }

  @override
  Future<Result<Failure, void>> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _remote.confirmPasswordReset(
        token: token,
        newPassword: newPassword,
      );
      return const Result.ok(null);
    } on ApiException catch (e) {
      return Result.err(e.failure);
    }
    // Deliberate catch-all: repository boundary, same reasoning as login()
    // above — any unanticipated exception still becomes a Result.err.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        UnexpectedFailure('Something went wrong. Please try again.'),
      );
    }
  }

  @override
  Future<Result<Failure, void>> deleteAccount() async {
    try {
      // Confirm the server-side deletion succeeded *before* touching any
      // local state: if this call fails, the account still exists and the
      // user must stay logged in with a clear error, not be logged out
      // speculatively.
      await _remote.deleteAccount();
      await _tokenStorage.clear();
      _emitLoggedOut();
      return const Result.ok(null);
    } on ApiException catch (e) {
      return Result.err(e.failure);
    }
    // Deliberate catch-all: repository boundary, same reasoning as login()
    // above — any unanticipated exception still becomes a Result.err.
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
}
