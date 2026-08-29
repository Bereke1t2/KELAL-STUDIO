import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/export/data/datasources/gallery_datasource.dart';
import 'package:kelal_studio/features/export/data/datasources/share_datasource.dart';
import 'package:kelal_studio/features/export/domain/entities/export_failure.dart';
import 'package:kelal_studio/features/export/domain/repositories/export_repository.dart';

/// The only place that catches `gal`/`share_plus` exceptions and converts
/// them to [Result] — per `flutter-architecture`'s layering rule,
/// exceptions are allowed inside a data source but must never escape a
/// repository implementation.
@Injectable(as: ExportRepository)
class ExportRepositoryImpl implements ExportRepository {
  const ExportRepositoryImpl(this._galleryDataSource, this._shareDataSource);

  final GalleryDataSource _galleryDataSource;
  final ShareDataSource _shareDataSource;

  @override
  Future<Result<ExportFailure, void>> saveToGallery(Uint8List pngBytes) async {
    try {
      await _galleryDataSource.saveImageBytes(pngBytes);
      return const Result.ok(null);
    } on GalleryAccessDeniedException {
      return const Result.err(
        ExportFailure(
          type: ExportFailureType.galleryPermissionDenied,
          message: 'Gallery access denied (requestAccess returned false).',
        ),
      );
    } on GalException catch (e) {
      return Result.err(_mapGalException(e));
    }
    // gal's own documented contract is "throws GalException on any
    // failure," but nothing stops a lower-level platform channel error
    // (e.g. a MissingPluginException in a misconfigured test host) from
    // surfacing some other exception type — collapsed to `unknown` rather
    // than letting it escape this repository boundary unmapped.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        ExportFailure(
          type: ExportFailureType.unknown,
          message: 'Unexpected error saving to gallery.',
        ),
      );
    }
  }

  ExportFailure _mapGalException(GalException e) {
    return switch (e.type) {
      GalExceptionType.accessDenied => const ExportFailure(
        type: ExportFailureType.galleryPermissionDenied,
        message: 'Gallery access denied.',
      ),
      GalExceptionType.notEnoughSpace ||
      GalExceptionType.notSupportedFormat => ExportFailure(
        type: ExportFailureType.galleryWriteFailed,
        message: e.type.message,
      ),
      GalExceptionType.unexpected => const ExportFailure(
        type: ExportFailureType.unknown,
        message: 'Unexpected gal error.',
      ),
    };
  }

  @override
  Future<Result<ExportFailure, void>> shareImage({
    required Uint8List pngBytes,
    String? text,
  }) async {
    try {
      await _shareDataSource.shareImageBytes(bytes: pngBytes, text: text);
      return const Result.ok(null);
    }
    // share_plus documents `share()` as able to throw a platform exception
    // on genuine failure (distinct from a user simply dismissing the
    // sheet, which resolves normally with `ShareResultStatus.dismissed` —
    // see SharePlusDataSource's doc comment) — no more specific exception
    // type is documented to switch on, so this collapses to one failure
    // type rather than guessing at a taxonomy the package doesn't expose.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        ExportFailure(
          type: ExportFailureType.shareFailed,
          message: 'Share sheet invocation failed.',
        ),
      );
    }
  }
}
