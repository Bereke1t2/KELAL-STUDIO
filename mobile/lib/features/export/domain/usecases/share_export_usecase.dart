import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/export/domain/entities/export_failure.dart';
import 'package:kelal_studio/features/export/domain/repositories/export_repository.dart';

/// Thin pass-through over [ExportRepository.shareImage] — see
/// `SaveExportToGalleryUseCase`'s doc comment for the same reasoning.
@injectable
class ShareExportUseCase {
  const ShareExportUseCase(this._repository);

  final ExportRepository _repository;

  Future<Result<ExportFailure, void>> call({
    required Uint8List pngBytes,
    String? text,
  }) {
    return _repository.shareImage(pngBytes: pngBytes, text: text);
  }
}
