import 'package:dio/dio.dart';

import 'package:kelal_studio/core/error/result.dart';

/// Maps transport-level (dio) errors and the backend's typed error taxonomy
/// (PRD §11: `quota_exceeded`, `provider_timeout`, `moderation_refused`,
/// `malformed_output`, `validation_error`) into [ApiFailure].
///
/// This is the *only* place dio exceptions should be caught and translated.
/// Everything above a data source deals in [ApiFailure], never in
/// [DioException] or raw HTTP status codes — see
/// mobile/.claude/skills/flutter-networking-data/SKILL.md.
class ApiExceptionMapper {
  const ApiExceptionMapper();

  ApiFailure map(Object error) {
    if (error is DioException) return _mapDioException(error);
    return const ApiFailure(
      type: ApiErrorType.unknown,
      message: 'Something went wrong. Please try again.',
    );
  }

  ApiFailure _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return const ApiFailure(
          type: ApiErrorType.network,
          message: 'No connection. Check your network and try again.',
        );
      case DioExceptionType.cancel:
        return const ApiFailure(
          type: ApiErrorType.unknown,
          message: 'Request was cancelled.',
        );
      case DioExceptionType.badResponse:
        return _mapBadResponse(error);
      case DioExceptionType.badCertificate:
        return const ApiFailure(
          type: ApiErrorType.network,
          message: "Couldn't verify a secure connection. Please try again.",
        );
      case DioExceptionType.unknown:
        return const ApiFailure(
          type: ApiErrorType.unknown,
          message: 'Something went wrong. Please try again.',
        );
    }
  }

  ApiFailure _mapBadResponse(DioException error) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final errorCode = body is Map ? body['error_code'] as String? : null;

    if (status == 401) {
      return const ApiFailure(
        type: ApiErrorType.unauthorized,
        message: 'Your session expired. Please sign in again.',
      );
    }

    switch (errorCode) {
      case 'quota_exceeded':
        final resetsAtRaw = body is Map ? body['resets_at'] as String? : null;
        return ApiFailure(
          type: ApiErrorType.quotaExceeded,
          message: "You've used today's generation quota. It resets soon.",
          resetsAt: resetsAtRaw != null ? DateTime.tryParse(resetsAtRaw) : null,
        );
      case 'provider_timeout':
        return const ApiFailure(
          type: ApiErrorType.providerTimeout,
          message: 'Generation is taking longer than usual. Please try again.',
        );
      case 'moderation_refused':
        final reason = body is Map ? body['message'] as String? : null;
        return ApiFailure(
          type: ApiErrorType.moderationRefused,
          message:
              reason ??
              "This idea can't be generated. Please adjust it and try again.",
          moderationReason: reason,
        );
      case 'malformed_output':
        return const ApiFailure(
          type: ApiErrorType.malformedOutput,
          message: "We couldn't generate that. Please try again.",
        );
      case 'validation_error':
        return const ApiFailure(
          type: ApiErrorType.validationError,
          message: 'Please check your input and try again.',
        );
      default:
        return const ApiFailure(
          type: ApiErrorType.unknown,
          message: 'Something went wrong. Please try again.',
        );
    }
  }
}
