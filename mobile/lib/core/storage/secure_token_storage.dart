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

  /// Not a secret either — same reasoning as [_emailVerifiedKey] above.
  /// The real backend has no id-resolution endpoint for "my brand kit"
  /// (no `/brand-kits/me`, no user id in the login/register response — see
  /// `RealBrandKitRemoteDataSource`'s doc comment for the full contract-gap
  /// story), so the client generates its own id on first use and treats
  /// `PUT /brand-kits/{id}`'s owner-scoped upsert as "create mine here."
  /// Stored per-session (cleared alongside the tokens) rather than
  /// per-install: a **known, flagged limitation** this implies is that
  /// logging out and back in as the same user re-generates a fresh id,
  /// orphaning whatever kit the previous session created — there is no
  /// way to look it back up without a real id-resolution endpoint. Scoping
  /// this to the session (not persisting across logout) was still the
  /// better of two flawed options: the alternative (persist forever, keyed
  /// by nothing) would let a second account on the same device silently
  /// collide with the first account's kit id.
  static const _brandKitIdKey = 'kelal_brand_kit_id';

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

  Future<String?> readBrandKitId() => _storage.read(key: _brandKitIdKey);

  Future<void> saveBrandKitId(String id) =>
      _storage.write(key: _brandKitIdKey, value: id);

  /// Called on logout, account deletion, or detected refresh-token reuse
  /// (compromise signal per PRD §6.1) — always clear all session state
  /// together, never just the tokens.
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _emailVerifiedKey);
    await _storage.delete(key: _brandKitIdKey);
  }
}

@module
abstract class SecureStorageModule {
  @lazySingleton
  FlutterSecureStorage get flutterSecureStorage => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
}
