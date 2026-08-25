import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/generation/data/datasources/generation_remote_data_source.dart';
import 'package:kelal_studio/features/generation/data/models/generate_text_response_dto.dart';
import 'package:kelal_studio/features/generation/domain/entities/content_platform.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_result.dart';
import 'package:kelal_studio/features/generation/domain/entities/input_language.dart';
import 'package:kelal_studio/features/generation/domain/repositories/generation_repository.dart';

@LazySingleton(as: GenerationRepository)
class GenerationRepositoryImpl implements GenerationRepository {
  GenerationRepositoryImpl(this._remote);

  final GenerationRemoteDataSource _remote;

  GenerationResult _toDomain(GenerateTextResponseDto dto) => GenerationResult(
    captionEn: dto.captionEn,
    captionAm: dto.captionAm,
    callToAction: dto.callToAction,
    hashtags: dto.hashtags,
    isFallback: dto.isFallback,
  );

  @override
  Future<Result<Failure, GenerationResult>> generateText({
    required String inputText,
    required InputLanguage inputLanguage,
    required ContentPlatform platform,
    String? brandKitId,
  }) async {
    try {
      final dto = await _remote.generateText(
        inputText: inputText,
        inputLang: inputLanguage.wireValue,
        platform: platform.wireValue,
        brandKitId: brandKitId,
      );
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
}
