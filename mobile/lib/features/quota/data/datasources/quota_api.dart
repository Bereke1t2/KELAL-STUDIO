import 'package:dio/dio.dart' hide Headers;
import 'package:kelal_studio/features/quota/data/models/quota_dto.dart';
import 'package:retrofit/retrofit.dart';

part 'quota_api.g.dart';

/// Retrofit-generated real client, code-first but kept in sync by hand
/// with mobile/api_contract/openapi.yaml (`GET /quota/me`). Run
/// `dart run build_runner build` after editing. See
/// mobile/.claude/skills/flutter-networking-data/SKILL.md for why this
/// project doesn't (yet) auto-generate from the YAML directly.
@RestApi()
abstract class QuotaApi {
  factory QuotaApi(Dio dio, {String baseUrl}) = _QuotaApi;

  @GET('/quota/me')
  Future<QuotaDto> getMyQuota();
}
