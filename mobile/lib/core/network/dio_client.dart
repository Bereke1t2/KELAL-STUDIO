import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/env/env.dart';
import 'package:kelal_studio/core/network/auth_interceptor.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// The single [Dio] instance for the app. Every retrofit API client is
/// constructed from this instance so the auth/logging/error-mapping
/// pipeline is applied uniformly — no feature should construct its own
/// `Dio()`. See mobile/.claude/skills/flutter-networking-data/SKILL.md.
///
/// Certificate pinning is intentionally **not** wired here by default (PRD
/// §7.8: decide deliberately, don't default-on — it complicates incident
/// recovery). If/when it's turned on, it belongs in this module behind an
/// explicit config flag, not scattered across call sites.
@module
abstract class NetworkModule {
  @lazySingleton
  Dio dio(AuthInterceptor authInterceptor) {
    final dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    dio.interceptors.add(authInterceptor);

    // Verbose request/response logging must never ship in a release build —
    // it can leak prompts, tokens, or PII into device logs.
    assert(() {
      dio.interceptors.add(PrettyDioLogger(requestBody: true));
      return true;
    }(), 'debug-only: adds verbose request/response logging');

    return dio;
  }
}
