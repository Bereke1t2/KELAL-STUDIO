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

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  /// Called on logout, account deletion, or detected refresh-token reuse
  /// (compromise signal per PRD §6.1) — always clear both tokens together,
  /// never just one.
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

@module
abstract class SecureStorageModule {
  @lazySingleton
  FlutterSecureStorage get flutterSecureStorage => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
}
