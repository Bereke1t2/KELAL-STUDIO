import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/export/domain/entities/export_failure.dart';
import 'package:kelal_studio/features/export/domain/repositories/export_repository.dart';

/// Thin pass-through over [ExportRepository.saveToGallery] — see
/// `mobile/.claude/skills/flutter-architecture/SKILL.md`'s "one usecase
/// class per use case" rule; all the actual permission/exception-mapping
/// logic lives in the repository/data-source layer, not here.
@injectable
class SaveExportToGalleryUseCase {
  const SaveExportToGalleryUseCase(this._repository);

  final ExportRepository _repository;

  Future<Result<ExportFailure, void>> call(Uint8List pngBytes) {
    return _repository.saveToGallery(pngBytes);
  }
}
