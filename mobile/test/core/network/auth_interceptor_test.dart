import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/auth_interceptor.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/core/storage/secure_token_storage.dart';
import 'package:kelal_studio/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:kelal_studio/features/auth/data/models/auth_tokens_dto.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

void main() {
  late MockSecureTokenStorage tokenStorage;
  late MockAuthRemoteDataSource authRemoteDataSource;
  late AuthInterceptor interceptor;

  // A target that fails near-instantly on the post-refresh retry
  // (connection refused on localhost) rather than hitting the real
  // network — the retry path itself is pre-existing behavior this branch
  // deliberately doesn't touch; only `_refresh()`'s wiring is under test.
  RequestOptions requestOptions() =>
      RequestOptions(path: 'http://127.0.0.1:1/protected');

  DioException unauthorizedError() {
    final options = requestOptions();
    return DioException(
      requestOptions: options,
      response: Response(requestOptions: options, statusCode: 401),
      type: DioExceptionType.badResponse,
    );
  }

  setUp(() {
    tokenStorage = MockSecureTokenStorage();
    authRemoteDataSource = MockAuthRemoteDataSource();
    interceptor = AuthInterceptor(tokenStorage);
    // Mirrors how AuthDataSourceModule registers this in the real app —
    // AuthInterceptor resolves it lazily via getIt (see the doc comment on
    // AuthInterceptor._refresh for why).
    getIt.registerLazySingleton<AuthRemoteDataSource>(
      () => authRemoteDataSource,
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('no stored refresh token: never resolves AuthRemoteDataSource, clears '
      'tokens, and forwards the original error', () async {
    when(() => tokenStorage.readRefreshToken()).thenAnswer((_) async => null);
    when(() => tokenStorage.clear()).thenAnswer((_) async {});

    final handler = MockErrorInterceptorHandler();
    final err = unauthorizedError();

    await interceptor.onError(err, handler);

    verifyNever(
      () => authRemoteDataSource.refresh(
        refreshToken: any(named: 'refreshToken'),
      ),
    );
    verify(() => tokenStorage.clear()).called(1);
    verify(() => handler.next(err)).called(1);
  });

  test('a refresh call that fails (reuse/expiry -> ApiException) clears '
      'tokens and forwards the original error, never silently reissuing '
      'tokens (PRD §6.1)', () async {
    when(
      () => tokenStorage.readRefreshToken(),
    ).thenAnswer((_) async => 'stale-refresh-token');
    when(() => tokenStorage.clear()).thenAnswer((_) async {});
    when(
      () => authRemoteDataSource.refresh(refreshToken: 'stale-refresh-token'),
    ).thenThrow(
      ApiException(
        const ApiFailure(
          type: ApiErrorType.unauthorized,
          message: 'Your session expired. Please sign in again.',
        ),
      ),
    );

    final handler = MockErrorInterceptorHandler();
    final err = unauthorizedError();

    await interceptor.onError(err, handler);

    verify(
      () => authRemoteDataSource.refresh(refreshToken: 'stale-refresh-token'),
    ).called(1);
    verify(() => tokenStorage.clear()).called(1);
    verify(() => handler.next(err)).called(1);
  });

  test('a successful refresh persists the newly-rotated tokens via '
      'SecureTokenStorage, going through AuthRemoteDataSource (respecting '
      'Env.useMockApi) rather than a hand-rolled bare-Dio() call', () async {
    when(
      () => tokenStorage.readRefreshToken(),
    ).thenAnswer((_) async => 'valid-refresh-token');
    when(
      () => authRemoteDataSource.refresh(refreshToken: 'valid-refresh-token'),
    ).thenAnswer(
      (_) async => const AuthTokensDto(
        accessToken: 'new-access-token',
        refreshToken: 'new-refresh-token',
        emailVerified: true,
      ),
    );
    when(
      () => tokenStorage.saveTokens(
        accessToken: 'new-access-token',
        refreshToken: 'new-refresh-token',
      ),
    ).thenAnswer((_) async {});
    // The post-refresh retry re-reads the access token for the
    // Authorization header — pre-existing behavior, not under test here.
    when(
      () => tokenStorage.readAccessToken(),
    ).thenAnswer((_) async => 'new-access-token');

    final handler = MockErrorInterceptorHandler();
    final err = unauthorizedError();

    await interceptor.onError(err, handler);

    verify(
      () => tokenStorage.saveTokens(
        accessToken: 'new-access-token',
        refreshToken: 'new-refresh-token',
      ),
    ).called(1);
    // A successful refresh must never clear tokens.
    verifyNever(() => tokenStorage.clear());
  });
}
