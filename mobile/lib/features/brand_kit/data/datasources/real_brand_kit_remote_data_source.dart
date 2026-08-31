import 'dart:typed_data';

import 'package:dio/dio.dart' show DioException, DioMediaType, MultipartFile;
import 'package:kelal_studio/core/network/api_exception_mapper.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/core/storage/secure_token_storage.dart';
import 'package:kelal_studio/features/brand_kit/data/datasources/brand_kit_api.dart';
import 'package:kelal_studio/features/brand_kit/data/datasources/brand_kit_remote_data_source.dart';
import 'package:kelal_studio/features/brand_kit/data/datasources/fake_brand_kit_remote_data_source.dart'
    show FakeBrandKitRemoteDataSource;
import 'package:kelal_studio/features/brand_kit/data/models/asset_dto.dart';
import 'package:kelal_studio/features/brand_kit/data/models/brand_kit_dto.dart';
import 'package:uuid/uuid.dart';

/// Wraps the generated [BrandKitApi], translating every [DioException] into
/// an [ApiException] at the boundary — same shape as
/// `features/auth/data/datasources/real_auth_remote_data_source.dart`.
/// Selected instead of [FakeBrandKitRemoteDataSource] by
/// `brand_kit_datasource_module.dart` when `Env.useMockApi` is false.
///
/// **Id resolution (fixed; was a real, documented gap — see
/// `SecureTokenStorage._brandKitIdKey`'s doc comment for the full story
/// and its known remaining limitation)**: `/brand-kits/{id}` needs a real
/// UUID, and the contract gives the client no way to learn one for its own
/// account — no `/brand-kits/me`, no user id anywhere in the auth
/// response. Since backend's `PUT` is a deliberate owner-scoped upsert
/// (docs/OPEN_QUESTIONS.md → brandkit-creation: creates at the
/// client-supplied id if none exists), the client generating its own id on
/// first use and always addressing that id is the correct way to use this
/// contract as designed — not a workaround. [_resolveBrandKitId] does
/// exactly that, persisting the chosen id via [SecureTokenStorage] so the
/// same id is reused for the rest of the session.
class RealBrandKitRemoteDataSource implements BrandKitRemoteDataSource {
  RealBrandKitRemoteDataSource(this._api, this._tokenStorage);

  final BrandKitApi _api;
  final SecureTokenStorage _tokenStorage;
  static const _mapper = ApiExceptionMapper();
  static const _uuid = Uuid();

  Future<String> _resolveBrandKitId() async {
    final existing = await _tokenStorage.readBrandKitId();
    if (existing != null) return existing;
    final generated = _uuid.v4();
    await _tokenStorage.saveBrandKitId(generated);
    return generated;
  }

  @override
  Future<BrandKitDto> getBrandKit() async {
    try {
      final id = await _resolveBrandKitId();
      return await _api.getBrandKit(id);
    } catch (error) {
      throw ApiException(_mapper.map(error));
    }
  }

  @override
  Future<BrandKitDto> updateBrandKit(BrandKitDto brandKit) async {
    try {
      final id = await _resolveBrandKitId();
      return await _api.updateBrandKit(id, {
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
  Future<AssetDto> uploadAsset({
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
