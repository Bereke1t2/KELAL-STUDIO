import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/generation/domain/entities/content_platform.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_result.dart';
import 'package:kelal_studio/features/generation/domain/entities/input_language.dart';
import 'package:kelal_studio/features/generation/domain/repositories/generation_repository.dart';
import 'package:kelal_studio/features/generation/domain/usecases/generate_text_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockGenerationRepository extends Mock implements GenerationRepository {}

void main() {
  late MockGenerationRepository repository;
  late GenerateTextUseCase useCase;

  const result = GenerationResult(
    captionEn: 'Check out our new arrivals!',
    captionAm: 'አዲስ ምርቶቻችንን ይመልከቱ!',
    callToAction: 'Shop now',
    hashtags: ['#new', '#shop'],
    isFallback: false,
  );

  setUp(() {
    repository = MockGenerationRepository();
    useCase = GenerateTextUseCase(repository);
  });

  test('delegates to GenerationRepository.generateText with the same '
      'params and returns its result unchanged', () async {
    when(
      () => repository.generateText(
        inputText: 'New arrivals',
        inputLanguage: InputLanguage.en,
        platform: ContentPlatform.instagram,
        brandKitId: 'brand-kit-1',
      ),
    ).thenAnswer((_) async => const Result.ok(result));

    final outcome = await useCase(
      inputText: 'New arrivals',
      inputLanguage: InputLanguage.en,
      platform: ContentPlatform.instagram,
      brandKitId: 'brand-kit-1',
    );

    // Result/Ok/Err have no `==` override (see core/error/result.dart) —
    // compare the unwrapped, Equatable GenerationResult instead.
    expect(outcome.valueOrNull, result);
    verify(
      () => repository.generateText(
        inputText: 'New arrivals',
        inputLanguage: InputLanguage.en,
        platform: ContentPlatform.instagram,
        brandKitId: 'brand-kit-1',
      ),
    ).called(1);
  });

  test(
    'passes a null brandKitId through unchanged when none is resolved',
    () async {
      when(
        () => repository.generateText(
          inputText: 'New arrivals',
          inputLanguage: InputLanguage.auto,
          platform: ContentPlatform.telegram,
        ),
      ).thenAnswer((_) async => const Result.ok(result));

      await useCase(
        inputText: 'New arrivals',
        inputLanguage: InputLanguage.auto,
        platform: ContentPlatform.telegram,
      );

      verify(
        () => repository.generateText(
          inputText: 'New arrivals',
          inputLanguage: InputLanguage.auto,
          platform: ContentPlatform.telegram,
        ),
      ).called(1);
    },
  );

  test('propagates a failure unchanged', () async {
    when(
      () => repository.generateText(
        inputText: 'New arrivals',
        inputLanguage: InputLanguage.en,
        platform: ContentPlatform.instagram,
      ),
    ).thenAnswer(
      (_) async => const Result.err(
        ApiFailure(
          type: ApiErrorType.network,
          message: 'No connection. Check your network and try again.',
        ),
      ),
    );

    final outcome = await useCase(
      inputText: 'New arrivals',
      inputLanguage: InputLanguage.en,
      platform: ContentPlatform.instagram,
    );

    expect(outcome.isErr, isTrue);
  });
}
