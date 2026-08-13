import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:kelal_studio/features/auth/data/models/auth_tokens_dto.dart';

/// Professional fake: realistic latency, a small seeded user store, and the
/// exact PRD-mandated failure behavior — "wrong password -> generic
/// 'invalid credentials', never reveal which field" (PRD §6.1) — so the
/// login screen's error UI gets exercised honestly during development,
/// before any real backend exists. See
/// mobile/.claude/skills/flutter-networking-data/SKILL.md.
class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  final Map<String, String> _seededUsers = {
    'demo@kelalstudio.app': 'password123',
  };

  @override
  Future<AuthTokensDto> login({
    required String email,
    required String password,
  }) async {
    await FakeBackendSupport.latency();

    final storedPassword = _seededUsers[email];
    if (storedPassword == null || storedPassword != password) {
      throw ApiException(
        const ApiFailure(
          type: ApiErrorType.validationError,
          message: 'Invalid email or password.',
        ),
      );
    }

    final now = DateTime.now().microsecondsSinceEpoch;
    return AuthTokensDto(
      accessToken: 'fake-access-$now',
      refreshToken: 'fake-refresh-$now',
    );
  }
}
