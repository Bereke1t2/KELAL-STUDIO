import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:kelal_studio/features/auth/data/models/auth_tokens_dto.dart';

/// A seeded in-memory user record. Kept private — nothing outside this file
/// should reach into fake "backend" state directly.
class _FakeUser {
  _FakeUser({required this.password, required this.emailVerified});
  String password;
  bool emailVerified;
}

/// Professional fake: realistic latency, a small seeded user store, and the
/// exact PRD-mandated failure behavior — "wrong password -> generic
/// 'invalid credentials', never reveal which field" (PRD §6.1) — so the
/// login screen's error UI gets exercised honestly during development,
/// before any real backend exists. See
/// mobile/.claude/skills/flutter-networking-data/SKILL.md.
///
/// Also models two behaviors the real backend would enforce server-side,
/// so both are exercisable against the mock API:
///  - refresh-token rotation + reuse detection (PRD §6.1) — see [refresh].
///  - the anti-enumeration contract of [requestPasswordReset] — the
///    response never reveals whether the email is registered.
class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  final Map<String, _FakeUser> _seededUsers = {
    'demo@kelalstudio.app': _FakeUser(
      password: 'password123',
      // The seeded demo account is pre-verified so existing login-flow
      // manual testing/dev work isn't blocked by the new gate; freshly
      // *registered* accounts below start unverified, per PRD §6.1.
      emailVerified: true,
    ),
  };

  /// Refresh token -> owning email, for tokens that are still valid (i.e.
  /// issued but not yet consumed by a [refresh] call).
  final Map<String, String> _refreshTokenOwners = {};

  /// Refresh tokens that have already been consumed by exactly one
  /// [refresh] call. Presenting any of these again is treated as a
  /// compromise signal (PRD §6.1) rather than silently reissued.
  final Set<String> _consumedRefreshTokens = {};

  /// Password-reset token -> owning email, for tokens issued by
  /// [requestPasswordReset] and not yet consumed by [confirmPasswordReset].
  final Map<String, String> _passwordResetTokens = {};

  AuthTokensDto _issueTokens(String email) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final accessToken = 'fake-access-$now';
    final refreshToken = 'fake-refresh-$now';
    _refreshTokenOwners[refreshToken] = email;
    return AuthTokensDto(
      accessToken: accessToken,
      refreshToken: refreshToken,
      emailVerified: _seededUsers[email]!.emailVerified,
    );
  }

  @override
  Future<AuthTokensDto> login({
    required String email,
    required String password,
  }) async {
    await FakeBackendSupport.latency();

    final user = _seededUsers[email];
    if (user == null || user.password != password) {
      throw ApiException(
        const ApiFailure(
          type: ApiErrorType.validationError,
          message: 'Invalid email or password.',
        ),
      );
    }

    return _issueTokens(email);
  }

  @override
  Future<AuthTokensDto> register({
    required String email,
    required String password,
  }) async {
    await FakeBackendSupport.latency();

    if (_seededUsers.containsKey(email)) {
      throw ApiException(
        const ApiFailure(
          type: ApiErrorType.validationError,
          message: 'An account with this email already exists.',
        ),
      );
    }

    // Freshly-registered accounts start unverified — the
    // EmailVerificationGate exists precisely to be exercised by this.
    _seededUsers[email] = _FakeUser(password: password, emailVerified: false);
    return _issueTokens(email);
  }

  @override
  Future<AuthTokensDto> refresh({required String refreshToken}) async {
    await FakeBackendSupport.latency();

    if (_consumedRefreshTokens.contains(refreshToken)) {
      // Reuse of an already-consumed refresh token: a compromise signal,
      // not a soft retry — force full re-authentication (PRD §6.1).
      throw ApiException(
        const ApiFailure(
          type: ApiErrorType.unauthorized,
          message: 'Your session expired. Please sign in again.',
        ),
      );
    }

    final owner = _refreshTokenOwners[refreshToken];
    if (owner == null) {
      // Unknown token (never issued, or already rotated away in a way
      // this map no longer tracks) -> same unauthorized signal.
      throw ApiException(
        const ApiFailure(
          type: ApiErrorType.unauthorized,
          message: 'Your session expired. Please sign in again.',
        ),
      );
    }

    // First use of a valid refresh token: rotate it. The old token is
    // marked consumed and can never be reused; a fresh access/refresh pair
    // is issued in its place.
    _consumedRefreshTokens.add(refreshToken);
    _refreshTokenOwners.remove(refreshToken);
    return _issueTokens(owner);
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await FakeBackendSupport.latency();

    // Deliberately no branch on the *response* here — whether or not the
    // email exists, this method returns identically (PRD §6.1
    // anti-enumeration). The side effect (issuing a reset token) only
    // happens for a real seeded user; a caller has no way to observe that
    // difference from this method's return value/timing alone.
    final user = _seededUsers[email];
    if (user != null) {
      // Deliberately deterministic (not timestamp-suffixed like
      // [_issueTokens]'s access/refresh tokens): a real backend would mail
      // an unguessable token to the user, which the mobile client never
      // sees directly — but since this fake *is* the only "backend" in
      // mock mode, deriving the token from the email lets tests exercise
      // confirmPasswordReset's success path deterministically without a
      // backdoor into private state. Safe here precisely because it's a
      // fake with no real security boundary to weaken.
      final token = 'fake-reset-token-for-$email';
      _passwordResetTokens[token] = email;
    }
  }

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    await FakeBackendSupport.latency();

    final email = _passwordResetTokens.remove(token);
    if (email == null) {
      throw ApiException(
        const ApiFailure(
          type: ApiErrorType.validationError,
          message: 'This reset code is invalid or has expired.',
        ),
      );
    }

    _seededUsers[email]!.password = newPassword;
  }

  @override
  Future<void> deleteAccount() async {
    await FakeBackendSupport.latency();
    // The fake data source has no notion of "the current session" (unlike
    // the real backend, which derives the account from the bearer token) —
    // AuthApi.deleteAccount() takes no body/identifying parameter either,
    // by contract. This fake therefore always succeeds rather than
    // simulating removal of a specific seeded user; it exercises the
    // success/failure UI paths honestly but doesn't model "the deleted
    // account can no longer log in" end-to-end. Flagged as a known
    // simplification, not a silent gap.
  }
}
