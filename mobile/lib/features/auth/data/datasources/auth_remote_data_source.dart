import 'package:dio/dio.dart' show DioException;

import 'package:kelal_studio/core/network/fake_backend_support.dart'
    show ApiException;

import 'package:kelal_studio/features/auth/data/datasources/auth_api.dart'
    show AuthApi;

import 'package:kelal_studio/features/auth/data/datasources/fake_auth_remote_data_source.dart'
    show FakeAuthRemoteDataSource;

import 'package:kelal_studio/features/auth/data/models/auth_tokens_dto.dart';
import 'package:kelal_studio/features/auth/data/models/registration_result_dto.dart';

/// Implemented by both [AuthApi]-backed real data source and
/// [FakeAuthRemoteDataSource]. The repository depends only on this
/// interface — see mobile/.claude/skills/flutter-networking-data/SKILL.md
/// for the mock/real swap mechanism (`core/di/auth_datasource_module.dart`).
///
/// Throws [ApiException] (never a raw [DioException]) on failure — mapping
/// happens once, at the edge, via `core/network/api_exception_mapper.dart`.
abstract class AuthRemoteDataSource {
  Future<AuthTokensDto> login({
    required String email,
    required String password,
  });

  /// Does NOT establish a session — see [RegistrationResultDto]'s doc
  /// comment. The caller must [verifyEmail] then [login] separately.
  Future<RegistrationResultDto> register({
    required String email,
    required String password,
  });

  /// Consumes a purpose-bound verification token (from the account's
  /// verification email — see [resendVerification]) and returns whether
  /// the account is now verified. Idempotent: verifying an already-
  /// verified account still succeeds.
  Future<bool> verifyEmail({required String token});

  /// Always resolves regardless of whether [email] belongs to an existing
  /// or already-verified account (anti-enumeration, mirrors
  /// [requestPasswordReset]) — never throws to signal either.
  Future<void> resendVerification({required String email});

  /// Refresh tokens rotate on use (PRD §6.1): a successful call returns a
  /// freshly-issued access/refresh pair, and [refreshToken] itself must
  /// never be usable again. Presenting an already-consumed refresh token
  /// is a compromise signal and throws [ApiException] with
  /// `ApiErrorType.unauthorized` — see `FakeAuthRemoteDataSource`'s
  /// reuse-detection modeling.
  Future<AuthTokensDto> refresh({required String refreshToken});

  /// Always resolves regardless of whether [email] belongs to an existing
  /// account (PRD §6.1 anti-enumeration) — never throws to signal
  /// non-existence.
  Future<void> requestPasswordReset({required String email});

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  });

  /// Bearer-authenticated — the caller's access token is attached by
  /// `AuthInterceptor.onRequest`, nothing extra needed here.
  Future<void> deleteAccount();
}
