import 'dart:typed_data';

import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/brand_kit/domain/repositories/brand_kit_repository.dart';

/// One class per use case, single `call()` method — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md. Returns the new
/// asset's id only; the caller (`BrandKitBloc`) is responsible for saving
/// it onto a `BrandKit` via `UpdateBrandKitUseCase` for it to persist —
/// see `BrandKitRepository.uploadLogo`'s doc comment.
@injectable
class UploadBrandLogoUseCase {
  UploadBrandLogoUseCase(this._repository);

  final BrandKitRepository _repository;

  Future<Result<Failure, String>> call({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) {
    return _repository.uploadLogo(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );
  }
}
