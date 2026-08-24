import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/storage/secure_token_storage.dart';
import 'package:kelal_studio/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:kelal_studio/features/auth/data/models/auth_tokens_dto.dart';
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
    when(() => remote.login(email: email, password: password)).thenAnswer(
      (_) async => const AuthTokensDto(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    when(
      () => tokenStorage.saveTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
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
    when(() => remote.login(email: email, password: password)).thenAnswer(
      (_) async => const AuthTokensDto(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    when(
      () => tokenStorage.saveTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
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
}
