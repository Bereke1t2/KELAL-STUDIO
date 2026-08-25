import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/generation/domain/entities/content_platform.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_result.dart';
import 'package:kelal_studio/features/generation/domain/entities/input_language.dart';
import 'package:kelal_studio/features/generation/domain/repositories/generation_repository.dart';

/// One class per use case, single `call()` method — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md. Blocs call use
/// cases, never repositories directly.
@injectable
class GenerateTextUseCase {
  GenerateTextUseCase(this._repository);

  final GenerationRepository _repository;

  Future<Result<Failure, GenerationResult>> call({
    required String inputText,
    required InputLanguage inputLanguage,
    required ContentPlatform platform,
    String? brandKitId,
  }) => _repository.generateText(
    inputText: inputText,
    inputLanguage: inputLanguage,
    platform: platform,
    brandKitId: brandKitId,
  );
}
