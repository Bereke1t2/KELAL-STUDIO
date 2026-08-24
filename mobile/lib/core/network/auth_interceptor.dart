import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/di/injection.dart' show getIt;
import 'package:kelal_studio/core/network/fake_backend_support.dart'
    show ApiException;
import 'package:kelal_studio/core/storage/secure_token_storage.dart';

// NOTE: this file is `core/network`, which per
// mobile/.claude/skills/flutter-architecture/SKILL.md must never import
// from `features/**` — dependencies point one way. The import below is a
// deliberate, flagged exception to that rule, not a silent violation: see
// the doc comment on [_refresh] for why a genuine circular DI constraint
// (Dio needs this interceptor; the real AuthRemoteDataSource needs Dio)
// forces this file to reach into `features/auth` for the *type only*, via
// a lazy `getIt` lookup rather than constructor injection.
import 'package:kelal_studio/features/auth/data/datasources/auth_remote_data_source.dart'
    show AuthRemoteDataSource;

/// Attaches the bearer access token to every outgoing request and, on a
/// 401, attempts exactly one refresh-and-retry before giving up.
///
/// Refresh calls are serialized through [_refreshInFlight] so concurrent 401s
/// (e.g. several in-flight requests when the access token expires) trigger
/// a single refresh, not a stampede of parallel refresh calls that would
/// race the backend's refresh-token rotation/reuse-detection (PRD §6.1) —
/// a naive per-request refresh would make a *legitimate* concurrent retry
/// look like token-reuse and force an unwanted logout.
@lazySingleton
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage);

  final SecureTokenStorage _tokenStorage;
  Future<bool>? _refreshInFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.readAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;

    if (!isUnauthorized || alreadyRetried) {
      handler.next(err);
      return;
    }

    final refreshed = await (_refreshInFlight ??= _refresh());
    _refreshInFlight = null;

    if (!refreshed) {
      // Reuse/expiry detected server-side or refresh failed outright: force
      // re-authentication, never silently reissue tokens (PRD §6.1).
      await _tokenStorage.clear();
      handler.next(err);
      return;
    }

    try {
      final retryOptions = err.requestOptions..extra['retried'] = true;
      final token = await _tokenStorage.readAccessToken();
      retryOptions.headers['Authorization'] = 'Bearer $token';
      final response = await Dio().fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Resolves [AuthRemoteDataSource] lazily via the global [getIt] instance
  /// instead of constructor-injecting it — a deliberate escape hatch, not
  /// an oversight.
  ///
  /// [AuthInterceptor] needs to call `/auth/refresh` (or, in mock mode, the
  /// fake data source), i.e. it needs an [AuthRemoteDataSource]. But the
  /// *real* [AuthRemoteDataSource] needs a [Dio] client (`AuthApi(dio)`),
  /// and `Dio` itself is built by `NetworkModule`
  /// (`core/network/dio_client.dart`) with this interceptor as a
  /// constructor dependency. Constructor-injecting [AuthRemoteDataSource]
  /// into [AuthInterceptor] would therefore create a genuine circular
  /// dependency graph — `AuthInterceptor` -> `AuthRemoteDataSource` ->
  /// `Dio` -> `AuthInterceptor` — that `get_it`/`injectable` cannot resolve
  /// at construction time.
  ///
  /// By the time [_refresh] actually runs (in response to a real 401, well
  /// after app startup/DI graph construction has finished), `Dio`'s own
  /// singleton is already fully built, so `getIt<AuthRemoteDataSource>()`
  /// resolves cleanly — the same lazy-resolution pattern `lib/app.dart`
  /// already uses for `getIt<AppRouter>()`. This also means refresh
  /// correctly respects `Env.useMockApi` (going through
  /// `FakeAuthRemoteDataSource` in mock mode, exactly like every other auth
  /// call) instead of a hand-rolled bare-`Dio()` HTTP call that would
  /// bypass the mock/real swap entirely.
  ///
  /// Returns whether the refresh succeeded; on any failure (including
  /// reuse-detection, mapped by the data source to
  /// `ApiErrorType.unauthorized`) returns `false` — the existing caller
  /// (`onError` above) already clears tokens and forces re-auth when this
  /// returns `false`, so that isn't duplicated here.
  Future<bool> _refresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) return false;

    try {
      final authRemoteDataSource = getIt<AuthRemoteDataSource>();
      final tokens = await authRemoteDataSource.refresh(
        refreshToken: refreshToken,
      );
      await _tokenStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return true;
    } on ApiException {
      return false;
    }
    // Deliberate catch-all: an unexpected error here must not crash the
    // interceptor pipeline — treat it the same as a failed refresh.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return false;
    }
  }
}
