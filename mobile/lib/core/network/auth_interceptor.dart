import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/storage/secure_token_storage.dart';

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

  // TODO(auth-feature): wire to the real `/v1/auth/refresh` call once the
  // auth data source exists. Returns whether the refresh succeeded.
  Future<bool> _refresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) return false;
    return false;
  }
}
