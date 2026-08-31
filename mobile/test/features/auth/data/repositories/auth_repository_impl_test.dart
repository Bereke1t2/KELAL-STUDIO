import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/core/storage/secure_token_storage.dart';
import 'package:kelal_studio/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:kelal_studio/features/auth/data/models/auth_tokens_dto.dart';
import 'package:kelal_studio/features/auth/data/models/registration_result_dto.dart';
import 'package:kelal_studio/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

void main() {
  late MockAuthRemoteDataSource remote;
  late MockSecureTokenStorage tokenStorage;
  late AuthRepositoryImpl repository;

  const email = 'demo@kelalstudio.app';
  const password = 'password123';

  setUp(() {
    remote = MockAuthRemoteDataSource();
    tokenStorage = MockSecureTokenStorage();
    repository = AuthRepositoryImpl(remote, tokenStorage);
  });

  test('watchIsAuthenticated emits the seeded initial state, then true after '
      'a successful login() and false after logout()', () async {
    // No token stored yet -> seeded state is false.
    when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => null);
    when(() => tokenStorage.readEmailVerified()).thenAnswer((_) async => false);
    when(() => remote.login(email: email, password: password)).thenAnswer(
      (_) async => const AuthTokensDto(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        emailVerified: true,
      ),
    );
    when(
      () => tokenStorage.saveTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    ).thenAnswer((_) async {});
    when(
      () => tokenStorage.saveEmailVerified(verified: any(named: 'verified')),
    ).thenAnswer((_) async {});
    when(() => tokenStorage.clear()).thenAnswer((_) async {});

    final states = <bool>[];
    final subscription = repository.watchIsAuthenticated().listen(states.add);
    addTearDown(subscription.cancel);

    // The seed read is async (goes through readAccessToken()); let it
    // resolve before asserting.
    await pumpEventQueue();
    expect(states, [false]);

    await repository.login(email: email, password: password);
    // The controller isn't a `sync:` one, so event delivery to listeners is
    // microtask-scheduled — flush the queue before asserting.
    await pumpEventQueue();
    expect(states, [false, true]);

    await repository.logout();
    await pumpEventQueue();
    expect(states, [false, true, false]);

    verify(() => tokenStorage.readAccessToken()).called(1);
  });

  test('watchIsAuthenticated seeds true when a token already exists (e.g. '
      'app relaunch with an active session)', () async {
    when(
      () => tokenStorage.readAccessToken(),
    ).thenAnswer((_) async => 'existing-token');
    when(() => tokenStorage.readEmailVerified()).thenAnswer((_) async => true);

    final states = <bool>[];
    final subscription = repository.watchIsAuthenticated().listen(states.add);
    addTearDown(subscription.cancel);

    await pumpEventQueue();
    expect(states, [true]);
  });

  test('a second listener joining after the seed already fired does not '
      'trigger a second token-storage read, but still receives future '
      'emissions (broadcast stream, single seed)', () async {
    when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => null);
    when(() => tokenStorage.readEmailVerified()).thenAnswer((_) async => false);
    when(() => remote.login(email: email, password: password)).thenAnswer(
      (_) async => const AuthTokensDto(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        emailVerified: true,
      ),
    );
    when(
      () => tokenStorage.saveTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    ).thenAnswer((_) async {});
    when(
      () => tokenStorage.saveEmailVerified(verified: any(named: 'verified')),
    ).thenAnswer((_) async {});

    final firstStates = <bool>[];
    final firstSub = repository.watchIsAuthenticated().listen(firstStates.add);
    addTearDown(firstSub.cancel);
    await pumpEventQueue();
    expect(firstStates, [false]);

    final secondStates = <bool>[];
    final secondSub = repository.watchIsAuthenticated().listen(
      secondStates.add,
    );
    addTearDown(secondSub.cancel);

    await repository.login(email: email, password: password);
    await pumpEventQueue();

    // Only the first subscribe triggered the seed read.
    verify(() => tokenStorage.readAccessToken()).called(1);
    // The second listener joined after the seed had already fired (a
    // broadcast stream doesn't replay past events), so it missed the
    // seeded `false` but still gets the subsequent login emission.
    expect(secondStates, [true]);
    expect(firstStates, [false, true]);
  });

  test('register() does not establish a session — no tokens/email-verified '
      'state is persisted, and watchIsAuthenticated/watchEmailVerified never '
      'emit as a side effect of it (PRD §11, register-verification)', () async {
    when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => null);
    when(() => tokenStorage.readEmailVerified()).thenAnswer((_) async => false);
    when(() => remote.register(email: email, password: password)).thenAnswer(
      (_) async =>
          const RegistrationResultDto(userId: 'user-1', verificationSent: true),
    );

    final authStates = <bool>[];
    final authSub = repository.watchIsAuthenticated().listen(authStates.add);
    addTearDown(authSub.cancel);
    final verifiedStates = <bool>[];
    final verifiedSub = repository.watchEmailVerified().listen(
      verifiedStates.add,
    );
    addTearDown(verifiedSub.cancel);
    await pumpEventQueue();

    final result = await repository.register(email: email, password: password);
    await pumpEventQueue();

    expect(result.isOk, isTrue);
    result.when(
      ok: (outcome) {
        expect(outcome.userId, 'user-1');
        expect(outcome.verificationSent, isTrue);
      },
      err: (_) => fail('expected success'),
    );
    // Only the initial seed — no second emission from register().
    expect(authStates, [false]);
    expect(verifiedStates, [false]);
    verifyNever(
      () => tokenStorage.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    );
    verifyNever(
      () => tokenStorage.saveEmailVerified(verified: any(named: 'verified')),
    );
  });

  test('verifyEmail delegates to the remote data source and maps the '
      'verified flag through', () async {
    when(
      () => remote.verifyEmail(token: 'a-token'),
    ).thenAnswer((_) async => true);

    final result = await repository.verifyEmail(token: 'a-token');

    expect(result.isOk, isTrue);
    expect(result.valueOrNull, isTrue);
  });

  test('verifyEmail maps an ApiException to a Result.err', () async {
    when(() => remote.verifyEmail(token: 'bad-token')).thenThrow(
      ApiException(
        const ApiFailure(
          type: ApiErrorType.validationError,
          message: 'This verification link is invalid or has expired.',
        ),
      ),
    );

    final result = await repository.verifyEmail(token: 'bad-token');

    expect(result.isErr, isTrue);
  });

  test('resendVerificationEmail always resolves ok() unless a genuine '
      'transport failure occurs — anti-enumeration', () async {
    when(
      () => remote.resendVerification(email: email),
    ).thenAnswer((_) async {});

    final result = await repository.resendVerificationEmail(email: email);

    expect(result.isOk, isTrue);
  });

  test('deleteAccount clears local session and emits logged-out only after '
      'the remote call succeeds', () async {
    when(() => remote.deleteAccount()).thenAnswer((_) async {});
    when(() => tokenStorage.clear()).thenAnswer((_) async {});
    when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => 'token');
    when(() => tokenStorage.readEmailVerified()).thenAnswer((_) async => true);

    final authStates = <bool>[];
    final authSub = repository.watchIsAuthenticated().listen(authStates.add);
    addTearDown(authSub.cancel);
    final verifiedStates = <bool>[];
    final verifiedSub = repository.watchEmailVerified().listen(
      verifiedStates.add,
    );
    addTearDown(verifiedSub.cancel);
    await pumpEventQueue();

    final result = await repository.deleteAccount();
    await pumpEventQueue();

    expect(result.isOk, isTrue);
    expect(authStates, [true, false]);
    expect(verifiedStates, [true, false]);
    verify(() => tokenStorage.clear()).called(1);
  });

  test(
    'deleteAccount leaves local session untouched when the remote call '
    'fails — the user stays signed in, not logged out speculatively',
    () async {
      when(() => remote.deleteAccount()).thenThrow(
        ApiException(
          const ApiFailure(
            type: ApiErrorType.network,
            message: 'No connection. Check your network and try again.',
          ),
        ),
      );
      when(
        () => tokenStorage.readAccessToken(),
      ).thenAnswer((_) async => 'token');
      when(
        () => tokenStorage.readEmailVerified(),
      ).thenAnswer((_) async => true);

      final authStates = <bool>[];
      final authSub = repository.watchIsAuthenticated().listen(authStates.add);
      addTearDown(authSub.cancel);
      await pumpEventQueue();

      final result = await repository.deleteAccount();
      await pumpEventQueue();

      expect(result.isErr, isTrue);
      expect(authStates, [true]); // no logged-out emission
      verifyNever(() => tokenStorage.clear());
    },
  );
}
