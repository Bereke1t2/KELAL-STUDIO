import 'dart:typed_data';

import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/brand_kit/data/datasources/brand_kit_remote_data_source.dart';
import 'package:kelal_studio/features/brand_kit/data/models/brand_kit_dto.dart';
import 'package:kelal_studio/features/brand_kit/data/services/logo_upload_hardener.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';
import 'package:kelal_studio/features/brand_kit/domain/repositories/brand_kit_repository.dart';

@LazySingleton(as: BrandKitRepository)
class BrandKitRepositoryImpl implements BrandKitRepository {
  BrandKitRepositoryImpl(this._remote);

  final BrandKitRemoteDataSource _remote;

  // Instantiated directly (not DI-injected), same pattern as
  // `ApiExceptionMapper` in `RealAuthRemoteDataSource` — a small, stateless
  // helper with no dependencies of its own doesn't need a getIt
  // registration.
  static const _hardener = LogoUploadHardener();

  BrandKit _toDomain(BrandKitDto dto) => BrandKit(
    id: dto.id,
    brandName: dto.brandName,
    logoAssetId: dto.logoAssetId,
    primaryColorHex: dto.primaryColorHex,
    secondaryColorHex: dto.secondaryColorHex,
    toneOfVoice: dto.toneOfVoice,
    contactInfo: dto.contactInfo,
    updatedAt: dto.updatedAt,
  );

  BrandKitDto _toDto(BrandKit entity) => BrandKitDto(
    id: entity.id,
    brandName: entity.brandName,
    logoAssetId: entity.logoAssetId,
    primaryColorHex: entity.primaryColorHex,
    secondaryColorHex: entity.secondaryColorHex,
    toneOfVoice: entity.toneOfVoice,
    contactInfo: entity.contactInfo,
    updatedAt: entity.updatedAt,
  );

  @override
  Future<Result<Failure, BrandKit>> getBrandKit() async {
    try {
      final dto = await _remote.getBrandKit();
      return Result.ok(_toDomain(dto));
    } on ApiException catch (e) {
      return Result.err(e.failure);
    }
    // Deliberate catch-all: this is the repository boundary — per
    // flutter-architecture, nothing above this layer may throw, so any
    // exception type we didn't anticipate still needs to become a
    // Result.err rather than propagate.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        UnexpectedFailure('Something went wrong. Please try again.'),
      );
    }
  }

  @override
  Future<Result<Failure, BrandKit>> updateBrandKit(BrandKit brandKit) async {
    try {
      final dto = await _remote.updateBrandKit(_toDto(brandKit));
      return Result.ok(_toDomain(dto));
    } on ApiException catch (e) {
      return Result.err(e.failure);
    }
    // Deliberate catch-all: repository boundary, same reasoning as
    // getBrandKit() above.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        UnexpectedFailure('Something went wrong. Please try again.'),
      );
    }
  }

  @override
  Future<Result<Failure, String>> uploadLogo({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    // Defense-in-depth only (PRD §6.8) — re-encode/downscale before ever
    // reaching the network. See LogoUploadHardener's doc comment for the
    // exact, limited scope of what this check does and does not catch.
    final hardened = await _hardener.harden(bytes);
    return hardened.when(
      ok: (hardenedBytes) async {
        try {
          // The hardener always re-encodes to PNG regardless of the input
          // format, so the uploaded filename/mime type must reflect that —
          // uploading the original filename/mimeType here would lie about
          // what bytes are actually being sent.
          final pngFilename = '${_stripExtension(filename)}.png';
          final response = await _remote.uploadAsset(
            bytes: hardenedBytes,
            filename: pngFilename,
            mimeType: 'image/png',
          );
          return Result.ok(response.assetId);
        } on ApiException catch (e) {
          return Result.err(e.failure);
        }
        // Deliberate catch-all: repository boundary, same reasoning as
        // getBrandKit()/updateBrandKit() above — any unanticipated
        // exception still becomes a Result.err rather than propagate.
        // ignore: avoid_catches_without_on_clauses
        catch (_) {
          return const Result.err(
            UnexpectedFailure('Something went wrong. Please try again.'),
          );
        }
      },
      err: (failure) async => Result.err(failure),
    );
  }

  String _stripExtension(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex <= 0) return filename;
    return filename.substring(0, dotIndex);
  }
}
