import 'package:freezed_annotation/freezed_annotation.dart';

part 'generate_image_response_dto.freezed.dart';
part 'generate_image_response_dto.g.dart';

/// Wire model matching `GenerateImageResponse` in
/// mobile/api_contract/openapi.yaml. DTOs stay in `data/`; domain code only
/// sees `GenerationImageResult`
/// (../../domain/entities/generation_image_result.dart).
@freezed
abstract class GenerateImageResponseDto with _$GenerateImageResponseDto {
  const factory GenerateImageResponseDto({
    @JsonKey(name: 'asset_id') required String assetId,
    @JsonKey(name: 'image_url') required String imageUrl,
    required int width,
    required int height,
  }) = _GenerateImageResponseDto;

  factory GenerateImageResponseDto.fromJson(Map<String, dynamic> json) =>
      _$GenerateImageResponseDtoFromJson(json);
}
