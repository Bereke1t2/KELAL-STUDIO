import 'package:freezed_annotation/freezed_annotation.dart';

part 'upload_asset_response_dto.freezed.dart';
part 'upload_asset_response_dto.g.dart';

/// Wire model matching `UploadAssetResponse` in
/// mobile/api_contract/openapi.yaml (the flagged `/assets` addition — see
/// that schema's own doc comment).
@freezed
abstract class UploadAssetResponseDto with _$UploadAssetResponseDto {
  const factory UploadAssetResponseDto({
    @JsonKey(name: 'asset_id') required String assetId,
    @JsonKey(name: 'storage_ref') required String storageRef,
  }) = _UploadAssetResponseDto;

  factory UploadAssetResponseDto.fromJson(Map<String, dynamic> json) =>
      _$UploadAssetResponseDtoFromJson(json);
}
