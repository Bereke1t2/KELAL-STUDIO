import 'package:freezed_annotation/freezed_annotation.dart';

part 'generate_text_response_dto.freezed.dart';
part 'generate_text_response_dto.g.dart';

/// Wire model matching `GenerateTextResponse` in
/// mobile/api_contract/openapi.yaml. DTOs stay in `data/` — domain code
/// never sees this class, only `GenerationResult` (see
/// ../../domain/entities/generation_result.dart).
@freezed
abstract class GenerateTextResponseDto with _$GenerateTextResponseDto {
  const factory GenerateTextResponseDto({
    @JsonKey(name: 'caption_en') required String captionEn,
    @JsonKey(name: 'caption_am') required String captionAm,
    @JsonKey(name: 'call_to_action') required String callToAction,
    required List<String> hashtags,

    /// **Not part of the wire contract.** `GenerateTextResponse` in
    /// mobile/api_contract/openapi.yaml has no such field — a real
    /// backend's PRD §6.2 fallback-template substitution is meant to
    /// arrive as an ordinarily-shaped 200 response, so parsing an actual
    /// server response always defaults this to `false`
    /// (`includeFromJson`/`includeToJson: false` means the key is never
    /// read from or written to JSON at all). Only
    /// `FakeGenerationRemoteDataSource` ever constructs this `true`
    /// directly (Dart-side, not via `fromJson`), as a way to simulate that
    /// PRD-described behavior so `GenerationResult.isFallback` — and the
    /// UI's "showing a saved template" notice — has something real to
    /// exercise end-to-end in mock mode.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(false)
    bool isFallback,
  }) = _GenerateTextResponseDto;

  factory GenerateTextResponseDto.fromJson(Map<String, dynamic> json) =>
      _$GenerateTextResponseDtoFromJson(json);
}
