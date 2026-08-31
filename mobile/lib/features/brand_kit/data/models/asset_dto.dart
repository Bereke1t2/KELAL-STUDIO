import 'package:freezed_annotation/freezed_annotation.dart';

part 'asset_dto.freezed.dart';
part 'asset_dto.g.dart';

/// Wire model matching `Asset` in `backend/api/openapi.yaml` — `POST
/// /assets`'s real `201` response.
///
/// **Replaces the old `UploadAssetResponseDto` `{asset_id, storage_ref}`**
/// (from the mobile-local mock contract, `mobile/api_contract/openapi.yaml`):
/// the real backend's shape has no `storage_ref` at all — that was always
/// an internal-only detail — and calls the id field bare `id`, not
/// `asset_id`. The old shape was never actually reachable against a real
/// backend; parsing this response with the old DTO would throw on the
/// first real logo upload (both required fields missing).
@freezed
abstract class AssetDto with _$AssetDto {
  const factory AssetDto({
    required String id,
    required int width,
    required int height,
    @JsonKey(name: 'mime_type') required String mimeType,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _AssetDto;

  factory AssetDto.fromJson(Map<String, dynamic> json) =>
      _$AssetDtoFromJson(json);
}
