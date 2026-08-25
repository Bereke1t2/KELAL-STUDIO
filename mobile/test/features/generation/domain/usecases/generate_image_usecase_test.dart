import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/generation/domain/entities/aspect_ratio.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_image_result.dart';
import 'package:kelal_studio/features/generation/domain/repositories/generation_repository.dart';
import 'package:kelal_studio/features/generation/domain/usecases/generate_image_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockGenerationRepository extends Mock implements GenerationRepository {}

void main() {
  late MockGenerationRepository repository;
  late GenerateImageUseCase useCase;

  const result = GenerationImageResult(
    assetId: 'asset-1',
    imageUrl: 'https://picsum.photos/seed/1/1080/1080',
    width: 1080,
    height: 1080,
  );

  setUp(() {
    repository = MockGenerationRepository();
    useCase = GenerateImageUseCase(repository);
  });

  test('delegates to GenerationRepository.generateImage with the same '
      'params and returns its result unchanged', () async {
    when(
      () => repository.generateImage(
        captionEn: 'Check out our new arrivals!',
        aspectRatio: GenerationAspectRatio.oneToOne,
        brandKitId: 'brand-kit-1',
      ),
    ).thenAnswer((_) async => const Result.ok(result));

    final outcome = await useCase(
      captionEn: 'Check out our new arrivals!',
      aspectRatio: GenerationAspectRatio.oneToOne,
      brandKitId: 'brand-kit-1',
    );

    expect(outcome.valueOrNull, result);
    verify(
      () => repository.generateImage(
        captionEn: 'Check out our new arrivals!',
        aspectRatio: GenerationAspectRatio.oneToOne,
        brandKitId: 'brand-kit-1',
      ),
    ).called(1);
  });

  test('propagates a failure unchanged', () async {
    when(
      () => repository.generateImage(
        captionEn: 'Check out our new arrivals!',
        aspectRatio: GenerationAspectRatio.fourToFive,
        brandKitId: 'brand-kit-1',
      ),
    ).thenAnswer(
      (_) async => const Result.err(
        ApiFailure(
          type: ApiErrorType.quotaExceeded,
          message: "You've used today's generation quota. It resets soon.",
        ),
      ),
    );

    final outcome = await useCase(
      captionEn: 'Check out our new arrivals!',
      aspectRatio: GenerationAspectRatio.fourToFive,
      brandKitId: 'brand-kit-1',
    );

    expect(outcome.isErr, isTrue);
  });
}
