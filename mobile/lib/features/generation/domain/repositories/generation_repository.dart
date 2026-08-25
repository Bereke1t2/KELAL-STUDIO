import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/generation/domain/entities/aspect_ratio.dart';
import 'package:kelal_studio/features/generation/domain/entities/content_platform.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_image_result.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_result.dart';
import 'package:kelal_studio/features/generation/domain/entities/input_language.dart';

/// Interface only — no `dio`, no `retrofit` import here. The concrete
/// implementation (`data/repositories/generation_repository_impl.dart`)
/// picks a real or fake data source at construction time; nothing above
/// this interface knows or cares which. See
/// mobile/.claude/skills/flutter-networking-data/SKILL.md.
abstract class GenerationRepository {
  /// `POST /generate/text`.
  ///
  /// [brandKitId] is optional per `GenerateTextRequest` in
  /// mobile/api_contract/openapi.yaml (not in its `required:` list) — pass
  /// `null` when none could be resolved. See `GenerationBloc`'s doc
  /// comment for how the caller resolves it from the currently-loaded
  /// brand kit, and `RealBrandKitRemoteDataSource`'s doc comment for the
  /// separate, already-flagged gap in how a brand kit's id is resolved
  /// against a real backend at all.
  Future<Result<Failure, GenerationResult>> generateText({
    required String inputText,
    required InputLanguage inputLanguage,
    required ContentPlatform platform,
    String? brandKitId,
  });

  /// `POST /generate/image`.
  ///
  /// Unlike [generateText], [brandKitId] is **required** here —
  /// `GenerateImageRequest` lists `brand_kit_id` in its `required:` array
  /// (mobile/api_contract/openapi.yaml), not optional the way it is on
  /// `GenerateTextRequest`. Callers must resolve a real brand kit id
  /// before calling this — see `ImageGenerationBloc`'s doc comment for
  /// where that's enforced as a real blocking error rather than silently
  /// omitted the way [generateText] can afford to.
  Future<Result<Failure, GenerationImageResult>> generateImage({
    required String captionEn,
    required GenerationAspectRatio aspectRatio,
    required String brandKitId,
  });
}
