import 'package:dio/dio.dart' hide Headers;
import 'package:kelal_studio/features/auth/data/models/auth_tokens_dto.dart';
import 'package:retrofit/retrofit.dart';

part 'auth_api.g.dart';

/// Retrofit-generated real client, code-first but kept in sync by hand
/// with mobile/api_contract/openapi.yaml (paths, request/response shapes).
/// Run `dart run build_runner build` after editing. See
/// mobile/.claude/skills/flutter-networking-data/SKILL.md for why this
/// project doesn't (yet) auto-generate from the YAML directly.
@RestApi()
abstract class AuthApi {
  factory AuthApi(Dio dio, {String baseUrl}) = _AuthApi;

  @POST('/auth/login')
  Future<AuthTokensDto> login(@Body() Map<String, dynamic> body);
}
