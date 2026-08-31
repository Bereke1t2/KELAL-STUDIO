import 'dart:typed_data';

import 'package:kelal_studio/core/network/fake_backend_support.dart'
    show ApiException;

import 'package:kelal_studio/features/brand_kit/data/datasources/brand_kit_api.dart'
    show BrandKitApi;

import 'package:kelal_studio/features/brand_kit/data/datasources/fake_brand_kit_remote_data_source.dart'
    show FakeBrandKitRemoteDataSource;

import 'package:kelal_studio/features/brand_kit/data/models/asset_dto.dart';
import 'package:kelal_studio/features/brand_kit/data/models/brand_kit_dto.dart';

/// Implemented by both [BrandKitApi]-backed real data source and
/// [FakeBrandKitRemoteDataSource]. The repository depends only on this
/// interface — see mobile/.claude/skills/flutter-networking-data/SKILL.md
/// for the mock/real swap mechanism (`brand_kit_datasource_module.dart`).
///
/// Throws [ApiException] (never a raw `DioException`) on failure — mapping
/// happens once, at the edge, via `core/network/api_exception_mapper.dart`.
///
/// Deliberately id-less, unlike the raw `/brand-kits/{id}` REST path it's
/// backed by — resolving "which brand kit" is this data source's own
/// concern (trivial for the fake: one seeded kit; a real, once-per-session-
/// generated id for the real implementation — see
/// `RealBrandKitRemoteDataSource`'s doc comment), not something
/// `domain/`/`presentation/` should ever need to know about.
abstract class BrandKitRemoteDataSource {
  Future<BrandKitDto> getBrandKit();

  Future<BrandKitDto> updateBrandKit(BrandKitDto brandKit);

  Future<AssetDto> uploadAsset({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  });
}
