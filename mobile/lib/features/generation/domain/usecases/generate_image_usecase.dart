import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/generation/domain/entities/aspect_ratio.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_image_result.dart';
import 'package:kelal_studio/features/generation/domain/repositories/generation_repository.dart';

/// One class per use case, single `call()` method — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md. Blocs call use
/// cases, never repositories directly.
///
/// `brandKitId` is required (non-nullable), unlike `GenerateTextUseCase`'s
/// optional one — mirrors `GenerationRepository.generateImage`'s doc
/// comment. This use case does not itself resolve a brand kit id or
/// decide what to do if none exists; that resolution-and-blocking-check
/// happens in `ImageGenerationBloc`, same layering as
/// `GenerationBloc`/`GetBrandKitUseCase` for text generation.
@injectable
class GenerateImageUseCase {
  GenerateImageUseCase(this._repository);

  final GenerationRepository _repository;

  Future<Result<Failure, GenerationImageResult>> call({
    required String captionEn,
    required GenerationAspectRatio aspectRatio,
    required String brandKitId,
  }) => _repository.generateImage(
    captionEn: captionEn,
    aspectRatio: aspectRatio,
    brandKitId: brandKitId,
  );
}
