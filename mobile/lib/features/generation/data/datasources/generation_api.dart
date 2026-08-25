import 'package:dio/dio.dart' hide Headers;
import 'package:kelal_studio/features/generation/data/models/generate_text_response_dto.dart';
import 'package:retrofit/retrofit.dart';

part 'generation_api.g.dart';

/// Retrofit-generated real client, code-first but kept in sync by hand
/// with mobile/api_contract/openapi.yaml (`POST /generate/text`). Run
/// `dart run build_runner build` after editing. See
/// mobile/.claude/skills/flutter-networking-data/SKILL.md for why this
/// project doesn't (yet) auto-generate from the YAML directly.
@RestApi()
abstract class GenerationApi {
  factory GenerationApi(Dio dio, {String baseUrl}) = _GenerationApi;

  @POST('/generate/text')
  Future<GenerateTextResponseDto> generateText(
    @Body() Map<String, dynamic> body,
  );
}
