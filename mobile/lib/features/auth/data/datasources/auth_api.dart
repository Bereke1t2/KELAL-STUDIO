import 'package:dio/dio.dart' hide Headers;
import 'package:kelal_studio/features/auth/data/models/auth_tokens_dto.dart';
import 'package:kelal_studio/features/auth/data/models/registration_result_dto.dart';
import 'package:kelal_studio/features/auth/data/models/verify_email_result_dto.dart';
import 'package:retrofit/retrofit.dart';

part 'auth_api.g.dart';

/// Retrofit-generated real client, code-first but kept in sync by hand
/// with `backend/api/openapi.yaml` (paths, request/response shapes) — the
/// real backend's canonical contract, not the mobile-local mock one this
/// client was originally built against. Run `dart run build_runner build`
/// after editing. See mobile/.claude/skills/flutter-networking-data/SKILL.md
/// for why this project doesn't (yet) auto-generate from the YAML directly.
@RestApi()
abstract class AuthApi {
  factory AuthApi(Dio dio, {String baseUrl}) = _AuthApi;

  @POST('/auth/login')
  Future<AuthTokensDto> login(@Body() Map<String, dynamic> body);

  /// Does NOT establish a session — see `RegistrationResultDto`'s doc
  /// comment. `AuthTokensDto` was the old (mock-contract) return shape.
  @POST('/auth/register')
  Future<RegistrationResultDto> register(@Body() Map<String, dynamic> body);

  @POST('/auth/verify-email')
  Future<VerifyEmailResultDto> verifyEmail(@Body() Map<String, dynamic> body);

  /// Anti-enumeration, mirrors `requestPasswordReset` — always `200`
  /// regardless of whether the email exists or is already verified. The
  /// caller must never branch UI on this succeeding/failing in a way that
  /// implies account existence.
  @POST('/auth/verify-email/resend')
  Future<void> resendVerification(@Body() Map<String, dynamic> body);

  @POST('/auth/refresh')
  Future<AuthTokensDto> refresh(@Body() Map<String, dynamic> body);

  @POST('/auth/password-reset/request')
  Future<void> requestPasswordReset(@Body() Map<String, dynamic> body);

  @POST('/auth/password-reset/confirm')
  Future<void> confirmPasswordReset(@Body() Map<String, dynamic> body);

  /// Body-less, bearer-authenticated DELETE — the token is attached by
  /// `AuthInterceptor`, nothing extra needed here.
  @DELETE('/auth/account')
  Future<void> deleteAccount();
}
