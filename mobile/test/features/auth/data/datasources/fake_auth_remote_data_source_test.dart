import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/auth/data/datasources/fake_auth_remote_data_source.dart';

void main() {
  late FakeAuthRemoteDataSource dataSource;

  setUp(() {
    dataSource = FakeAuthRemoteDataSource();
  });

  group('register', () {
    test('a freshly-registered account starts unverified', () async {
      final tokens = await dataSource.register(
        email: 'new@kelalstudio.app',
        password: 'password123',
      );
      expect(tokens.emailVerified, isFalse);
    });

    test(
      'registering an already-used email throws a validation ApiException',
      () async {
        await dataSource.register(
          email: 'dup@kelalstudio.app',
          password: 'password123',
        );
        expect(
          () => dataSource.register(
            email: 'dup@kelalstudio.app',
            password: 'different',
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.failure.type,
              'type',
              ApiErrorType.validationError,
            ),
          ),
        );
      },
    );
  });

  group('login', () {
    test('the seeded demo account is pre-verified', () async {
      final tokens = await dataSource.login(
        email: 'demo@kelalstudio.app',
        password: 'password123',
      );
      expect(tokens.emailVerified, isTrue);
    });

    test('wrong password throws a generic validation ApiException', () async {
      expect(
        () =>
            dataSource.login(email: 'demo@kelalstudio.app', password: 'wrong'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('refresh — rotation and reuse detection (PRD §6.1)', () {
    test('a valid refresh token returns a freshly-rotated pair', () async {
      final initial = await dataSource.login(
        email: 'demo@kelalstudio.app',
        password: 'password123',
      );

      final rotated = await dataSource.refresh(
        refreshToken: initial.refreshToken,
      );

      expect(rotated.refreshToken, isNot(initial.refreshToken));
      expect(rotated.accessToken, isNot(initial.accessToken));
    });

    test(
      'presenting an already-consumed refresh token again throws '
      'ApiErrorType.unauthorized instead of silently reissuing tokens',
      () async {
        final initial = await dataSource.login(
          email: 'demo@kelalstudio.app',
          password: 'password123',
        );

        // First use: succeeds and rotates.
        await dataSource.refresh(refreshToken: initial.refreshToken);

        // Reuse of the now-consumed original token: treated as a
        // compromise signal, not a soft retry.
        expect(
          () => dataSource.refresh(refreshToken: initial.refreshToken),
          throwsA(
            isA<ApiException>().having(
              (e) => e.failure.type,
              'type',
              ApiErrorType.unauthorized,
            ),
          ),
        );
      },
    );

    test(
      'an unknown/never-issued refresh token is also unauthorized',
      () async {
        expect(
          () => dataSource.refresh(refreshToken: 'never-issued'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.failure.type,
              'type',
              ApiErrorType.unauthorized,
            ),
          ),
        );
      },
    );

    test(
      'the newly-rotated refresh token is itself usable exactly once',
      () async {
        final initial = await dataSource.login(
          email: 'demo@kelalstudio.app',
          password: 'password123',
        );
        final rotated = await dataSource.refresh(
          refreshToken: initial.refreshToken,
        );

        // The rotated token works once...
        final rotatedAgain = await dataSource.refresh(
          refreshToken: rotated.refreshToken,
        );
        expect(rotatedAgain.refreshToken, isNot(rotated.refreshToken));

        // ...and is then itself consumed.
        expect(
          () => dataSource.refresh(refreshToken: rotated.refreshToken),
          throwsA(isA<ApiException>()),
        );
      },
    );
  });

  group('requestPasswordReset — anti-enumeration (PRD §6.1)', () {
    test('resolves for a seeded (existing) email', () async {
      await expectLater(
        dataSource.requestPasswordReset(email: 'demo@kelalstudio.app'),
        completes,
      );
    });

    test('resolves identically for an email that does not exist — no '
        'exception, no distinguishable outcome', () async {
      await expectLater(
        dataSource.requestPasswordReset(email: 'nobody@kelalstudio.app'),
        completes,
      );
    });
  });

  group('confirmPasswordReset', () {
    test('a valid reset token updates the password so the new one logs in '
        'and the old one no longer works', () async {
      const email = 'reset-me@kelalstudio.app';
      await dataSource.register(email: email, password: 'oldpassword1');
      await dataSource.requestPasswordReset(email: email);

      await dataSource.confirmPasswordReset(
        token: 'fake-reset-token-for-$email',
        newPassword: 'newpassword1',
      );

      expect(
        () => dataSource.login(email: email, password: 'oldpassword1'),
        throwsA(isA<ApiException>()),
      );
      final tokens = await dataSource.login(
        email: email,
        password: 'newpassword1',
      );
      // Verification state is untouched by a password reset.
      expect(tokens.emailVerified, isFalse);
    });

    test('a reset token can only be consumed once', () async {
      const email = 'reset-once@kelalstudio.app';
      await dataSource.register(email: email, password: 'oldpassword1');
      await dataSource.requestPasswordReset(email: email);
      const token = 'fake-reset-token-for-$email';

      await dataSource.confirmPasswordReset(
        token: token,
        newPassword: 'newpassword1',
      );

      expect(
        () => dataSource.confirmPasswordReset(
          token: token,
          newPassword: 'yetanother1',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('an unknown/invalid token throws a validation ApiException', () async {
      expect(
        () => dataSource.confirmPasswordReset(
          token: 'not-a-real-token',
          newPassword: 'newpassword1',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.failure.type,
            'type',
            ApiErrorType.validationError,
          ),
        ),
      );
    });
  });

  group('deleteAccount', () {
    test('succeeds unconditionally', () async {
      await expectLater(dataSource.deleteAccount(), completes);
    });
  });
}
