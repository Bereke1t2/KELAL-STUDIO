import 'package:freezed_annotation/freezed_annotation.dart';

part 'brand_kit_dto.freezed.dart';
part 'brand_kit_dto.g.dart';

/// Wire model matching `BrandKit` in mobile/api_contract/openapi.yaml.
/// DTOs stay in `data/` — domain code never sees this class, only
/// `BrandKit` (see ../../domain/entities/brand_kit.dart).
///
/// The OpenAPI schema doesn't mark any of these fields `required:` — see
/// the doc comment on the domain entity for why they're non-nullable here
/// anyway (except [logoAssetId]).
@freezed
abstract class BrandKitDto with _$BrandKitDto {
  const factory BrandKitDto({
    required String id,
    @JsonKey(name: 'brand_name') required String brandName,
    @JsonKey(name: 'primary_color_hex') required String primaryColorHex,
    @JsonKey(name: 'secondary_color_hex') required String secondaryColorHex,
    @JsonKey(name: 'tone_of_voice') required String toneOfVoice,
    @JsonKey(name: 'contact_info') required String contactInfo,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'logo_asset_id') String? logoAssetId,
  }) = _BrandKitDto;

  factory BrandKitDto.fromJson(Map<String, dynamic> json) =>
      _$BrandKitDtoFromJson(json);
}
