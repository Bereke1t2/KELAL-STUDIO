import 'package:dio/dio.dart' show DioException;

import 'package:kelal_studio/core/network/api_exception_mapper.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/generation/data/datasources/fake_generation_remote_data_source.dart'
    show FakeGenerationRemoteDataSource;
import 'package:kelal_studio/features/generation/data/datasources/generation_api.dart';
import 'package:kelal_studio/features/generation/data/datasources/generation_remote_data_source.dart';
import 'package:kelal_studio/features/generation/data/models/generate_image_response_dto.dart';
import 'package:kelal_studio/features/generation/data/models/generate_text_response_dto.dart';

/// Wraps the generated [GenerationApi], translating every [DioException]
/// into an [ApiException] at the boundary — same shape as
/// `features/quota/data/datasources/real_quota_remote_data_source.dart`.
/// Selected instead of [FakeGenerationRemoteDataSource] by
/// `generation_datasource_module.dart` when `Env.useMockApi` is false.
///
/// Unlike `RealBrandKitRemoteDataSource`, `POST /generate/text` has no
/// id-in-path problem — `brand_kit_id` (when present) travels in the
/// request body, not the URL, so this class has no equivalent contract
/// gap to flag for *this* endpoint. (A caller still might not have a
/// resolved brand kit id to pass at all — see `GenerationRepository`'s
/// doc comment — but that's a caller-side concern, not something this
/// data source needs to work around.)
class RealGenerationRemoteDataSource implements GenerationRemoteDataSource {
  RealGenerationRemoteDataSource(this._api);

  final GenerationApi _api;
  static const _mapper = ApiExceptionMapper();

  @override
  Future<GenerateTextResponseDto> generateText({
    required String inputText,
    required String inputLang,
    required String platform,
    String? brandKitId,
  }) async {
    try {
      return await _api.generateText({
        'input_text': inputText,
        'input_lang': inputLang,
        'platform': platform,
        if (brandKitId != null) 'brand_kit_id': brandKitId,
      });
    } catch (error) {
      throw ApiException(_mapper.map(error));
    }
  }

  @override
  Future<GenerateImageResponseDto> generateImage({
    required String captionEn,
    required String aspectRatio,
    required String brandKitId,
  }) async {
    try {
      return await _api.generateImage({
        'caption_en': captionEn,
        'aspect_ratio': aspectRatio,
        'brand_kit_id': brandKitId,
      });
    } catch (error) {
      throw ApiException(_mapper.map(error));
    }
  }
}
