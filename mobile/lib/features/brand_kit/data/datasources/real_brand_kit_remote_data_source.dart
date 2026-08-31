import 'dart:typed_data';

import 'package:dio/dio.dart' show DioException, DioMediaType, MultipartFile;

import 'package:kelal_studio/core/network/api_exception_mapper.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/brand_kit/data/datasources/brand_kit_api.dart';
import 'package:kelal_studio/features/brand_kit/data/datasources/brand_kit_remote_data_source.dart';
import 'package:kelal_studio/features/brand_kit/data/datasources/fake_brand_kit_remote_data_source.dart'
    show FakeBrandKitRemoteDataSource;
import 'package:kelal_studio/features/brand_kit/data/models/brand_kit_dto.dart';
import 'package:kelal_studio/features/brand_kit/data/models/upload_asset_response_dto.dart';

/// Wraps the generated [BrandKitApi], translating every [DioException] into
/// an [ApiException] at the boundary — same shape as
/// `features/auth/data/datasources/real_auth_remote_data_source.dart`.
/// Selected instead of [FakeBrandKitRemoteDataSource] by
/// `brand_kit_datasource_module.dart` when `Env.useMockApi` is false.
///
/// **KNOWN CONTRACT GAP — flagged, not silently resolved** (per
/// mobile/.claude/skills/flutter-architecture/SKILL.md's standing "flag,
/// don't silently assume" rule, and mobile/CLAUDE.md's equivalent). The
/// real `/brand-kits/{id}` endpoint requires a UUID path parameter, but
/// nothing in mobile/api_contract/openapi.yaml lets the mobile client learn
/// its own brand kit's id: neither `AuthTokens` nor `User` carries a user
/// id in the login/register response, and there's no `/brand-kits/me` (or
/// equivalent "list my brand kits") endpoint. This branch was scoped to add
/// only the `/assets` upload endpoint to the contract (see this branch's
/// task), not to redesign brand-kit id resolution — so rather than
/// inventing new, unrequested API surface, this data source falls back to
/// a nil-UUID placeholder below.
///
/// **This makes every method on this class non-functional against any real
/// backend today.** That's harmless in practice — `Env.useMockApi` defaults
/// `true` and no real backend exists yet anywhere in this repo (see
/// mobile/CLAUDE.md) — but it is a real gap, not a cosmetic one: whoever
/// adds a real backend must add an id-resolution mechanism to the contract
/// (e.g. a `/brand-kits/me` alias, or a user id returned from
/// `/auth/login`) before this class can work, and should replace
/// [_placeholderBrandKitId] with the resolved value at that point.
class RealBrandKitRemoteDataSource implements BrandKitRemoteDataSource {
  RealBrandKitRemoteDataSource(this._api);

  final BrandKitApi _api;
  static const _mapper = ApiExceptionMapper();

  static const _placeholderBrandKitId = '00000000-0000-0000-0000-000000000000';

  @override
  Future<BrandKitDto> getBrandKit() async {
    try {
      return await _api.getBrandKit(_placeholderBrandKitId);
    } catch (error) {
      throw ApiException(_mapper.map(error));
    }
  }

  @override
  Future<BrandKitDto> updateBrandKit(BrandKitDto brandKit) async {
    try {
      return await _api.updateBrandKit(_placeholderBrandKitId, {
        'id': brandKit.id,
        'brand_name': brandKit.brandName,
        'logo_asset_id': brandKit.logoAssetId,
        'primary_color_hex': brandKit.primaryColorHex,
        'secondary_color_hex': brandKit.secondaryColorHex,
        'tone_of_voice': brandKit.toneOfVoice,
        'contact_info': brandKit.contactInfo,
        'updated_at': brandKit.updatedAt.toIso8601String(),
      });
    } catch (error) {
      throw ApiException(_mapper.map(error));
    }
  }

  @override
  Future<UploadAssetResponseDto> uploadAsset({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    try {
      final file = MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(mimeType),
      );
      return await _api.uploadAsset(file);
    } catch (error) {
      throw ApiException(_mapper.map(error));
    }
  }
}
