import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/network/auth_interceptor.dart'
    show AuthInterceptor;

/// JWT access/refresh token storage. Backed by platform secure storage
/// (Keychain on iOS, Keystore-backed EncryptedSharedPreferences on Android)
/// — **never** `shared_preferences` or any plain file, per PRD §6.1 and
/// mobile/.claude/skills/flutter-security/SKILL.md. This is the *only*
/// class in the app allowed to read/write tokens; everything else goes
/// through [AuthInterceptor] / the auth repository.
@lazySingleton
class SecureTokenStorage {
  SecureTokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'kelal_access_token';
  static const _refreshTokenKey = 'kelal_refresh_token';

  /// Not a secret — the email-verification bit itself is harmless to an
  /// attacker with device access, who would already have the tokens above.
  /// Stored here anyway (rather than `shared_preferences`) purely so it
  /// lives and clears alongside the session it describes, in one place,
  /// instead of introducing a second storage mechanism for one boolean.
  static const _emailVerifiedKey = 'kelal_email_verified';

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  /// Fails closed: absent (e.g. no session yet) reads as `false`, matching
  /// PRD §6.1's "gates content generation until verified" default.
  Future<bool> readEmailVerified() async {
    final raw = await _storage.read(key: _emailVerifiedKey);
    return raw == 'true';
  }

  Future<void> saveEmailVerified({required bool verified}) =>
      _storage.write(key: _emailVerifiedKey, value: verified.toString());

  /// Called on logout, account deletion, or detected refresh-token reuse
  /// (compromise signal per PRD §6.1) — always clear all session state
  /// together, never just the tokens.
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _emailVerifiedKey);
  }
}

@module
abstract class SecureStorageModule {
  @lazySingleton
  FlutterSecureStorage get flutterSecureStorage => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
}
