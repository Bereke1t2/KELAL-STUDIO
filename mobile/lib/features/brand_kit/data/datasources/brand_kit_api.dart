import 'package:dio/dio.dart' hide Headers;
import 'package:kelal_studio/features/brand_kit/data/models/brand_kit_dto.dart';
import 'package:kelal_studio/features/brand_kit/data/models/upload_asset_response_dto.dart';
import 'package:retrofit/retrofit.dart';

part 'brand_kit_api.g.dart';

/// Retrofit-generated real client, code-first but kept in sync by hand
/// with mobile/api_contract/openapi.yaml (paths, request/response shapes).
/// Run `dart run build_runner build` after editing. See
/// mobile/.claude/skills/flutter-networking-data/SKILL.md for why this
/// project doesn't (yet) auto-generate from the YAML directly.
@RestApi()
abstract class BrandKitApi {
  factory BrandKitApi(Dio dio, {String baseUrl}) = _BrandKitApi;

  @GET('/brand-kits/{id}')
  Future<BrandKitDto> getBrandKit(@Path('id') String id);

  @PUT('/brand-kits/{id}')
  Future<BrandKitDto> updateBrandKit(
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );

  /// Multipart upload — see the flagged `/assets` addition in
  /// mobile/api_contract/openapi.yaml. [file] is built by the caller via
  /// `MultipartFile.fromBytes` (see `RealBrandKitRemoteDataSource`), never
  /// a `dart:io File` — the raw bytes already came from `domain/`'s
  /// primitive-only `BrandKitRepository.uploadLogo` signature.
  @POST('/assets')
  @MultiPart()
  Future<UploadAssetResponseDto> uploadAsset(
    @Part(name: 'file') MultipartFile file,
  );
}
