import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/get_brand_kit_usecase.dart';
import 'package:kelal_studio/features/generation/domain/entities/content_platform.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_result.dart';
import 'package:kelal_studio/features/generation/domain/entities/input_language.dart';
import 'package:kelal_studio/features/generation/domain/usecases/generate_text_usecase.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/generation_bloc.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/generation_event.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/generation_state.dart';
import 'package:mocktail/mocktail.dart';

class MockGenerateTextUseCase extends Mock implements GenerateTextUseCase {}

class MockGetBrandKitUseCase extends Mock implements GetBrandKitUseCase {}

void main() {
  late MockGenerateTextUseCase generateTextUseCase;
  late MockGetBrandKitUseCase getBrandKitUseCase;

  final brandKit = BrandKit(
    id: 'brand-kit-1',
    brandName: 'Demo Business',
    logoAssetId: null,
    primaryColorHex: '#855312',
    secondaryColorHex: '#C6821F',
    toneOfVoice: '',
    contactInfo: '',
    updatedAt: DateTime.utc(2026),
  );

  const result = GenerationResult(
    captionEn: 'Check out our new arrivals!',
    captionAm: 'አዲስ ምርቶቻችንን ይመልከቱ!',
    callToAction: 'Shop now',
    hashtags: ['#new', '#shop'],
    isFallback: false,
  );

  const fallbackResult = GenerationResult(
    captionEn: "Here's a starting point you can edit.",
    captionAm: 'ሊያርትዑት የሚችሉት መነሻ ነጥብ።',
    callToAction: 'Tell us what you think!',
    hashtags: ['#KelalStudio', '#SmallBusiness'],
    isFallback: true,
  );

  const event = GenerationRequested(
    inputText: 'New arrivals',
    inputLanguage: InputLanguage.en,
    platform: ContentPlatform.instagram,
  );

  setUp(() {
    generateTextUseCase = MockGenerateTextUseCase();
    getBrandKitUseCase = MockGetBrandKitUseCase();
    // Default happy-path stub for the brand-kit resolution step every
    // test implicitly goes through — individual tests override this when
    // they specifically care about the id-resolution-failure path.
    when(getBrandKitUseCase.call).thenAnswer((_) async => Result.ok(brandKit));
  });

  GenerationBloc buildBloc() =>
      GenerationBloc(generateTextUseCase, getBrandKitUseCase);

  group('GenerationRequested', () {
    blocTest<GenerationBloc, GenerationState>(
      'emits [InProgress, Success] on a successful generation, resolving '
      'brand_kit_id from the currently-loaded brand kit',
      setUp: () {
        when(
          () => generateTextUseCase(
            inputText: 'New arrivals',
            inputLanguage: InputLanguage.en,
            platform: ContentPlatform.instagram,
            brandKitId: 'brand-kit-1',
          ),
        ).thenAnswer((_) async => const Result.ok(result));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(event),
      expect: () => [
        const GenerationInProgress(),
        const GenerationSuccess(result),
      ],
      verify: (_) {
        verify(
          () => generateTextUseCase(
            inputText: 'New arrivals',
            inputLanguage: InputLanguage.en,
            platform: ContentPlatform.instagram,
            brandKitId: 'brand-kit-1',
          ),
        ).called(1);
      },
    );

    blocTest<GenerationBloc, GenerationState>(
      'still generates with brandKitId: null when resolving the current '
      'brand kit fails — an unrelated feature failing must not block '
      'generation, since brand_kit_id is optional on the wire',
      setUp: () {
        when(getBrandKitUseCase.call).thenAnswer(
          (_) async => const Result.err(
            ApiFailure(
              type: ApiErrorType.network,
              message: 'No connection. Check your network and try again.',
            ),
          ),
        );
        when(
          () => generateTextUseCase(
            inputText: 'New arrivals',
            inputLanguage: InputLanguage.en,
            platform: ContentPlatform.instagram,
          ),
        ).thenAnswer((_) async => const Result.ok(result));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(event),
      expect: () => [
        const GenerationInProgress(),
        const GenerationSuccess(result),
      ],
      verify: (_) {
        verify(
          () => generateTextUseCase(
            inputText: 'New arrivals',
            inputLanguage: InputLanguage.en,
            platform: ContentPlatform.instagram,
          ),
        ).called(1);
      },
    );

    blocTest<GenerationBloc, GenerationState>(
      'emits [InProgress, Success] with isFallback: true on the PRD §6.2 '
      'fallback-template path',
      setUp: () {
        when(
          () => generateTextUseCase(
            inputText: 'New arrivals',
            inputLanguage: InputLanguage.en,
            platform: ContentPlatform.instagram,
            brandKitId: 'brand-kit-1',
          ),
        ).thenAnswer((_) async => const Result.ok(fallbackResult));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(event),
      expect: () => [
        const GenerationInProgress(),
        const GenerationSuccess(fallbackResult),
      ],
      verify: (_) {
        expect(fallbackResult.isFallback, isTrue);
      },
    );

    for (final type in [
      ApiErrorType.quotaExceeded,
      ApiErrorType.providerTimeout,
      ApiErrorType.moderationRefused,
      ApiErrorType.malformedOutput,
      ApiErrorType.validationError,
      ApiErrorType.network,
      ApiErrorType.unauthorized,
      ApiErrorType.unknown,
    ]) {
      final failure = ApiFailure(type: type, message: 'failure: $type');

      blocTest<GenerationBloc, GenerationState>(
        'emits [InProgress, Failure] carrying the ApiFailure for '
        '$type',
        setUp: () {
          when(
            () => generateTextUseCase(
              inputText: 'New arrivals',
              inputLanguage: InputLanguage.en,
              platform: ContentPlatform.instagram,
              brandKitId: 'brand-kit-1',
            ),
          ).thenAnswer((_) async => Result.err(failure));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(event),
        expect: () => [
          const GenerationInProgress(),
          GenerationFailure(failure),
        ],
      );
    }

    blocTest<GenerationBloc, GenerationState>(
      'normalizes a non-ApiFailure (e.g. UnexpectedFailure from the '
      "repository's catch-all) into an ApiFailure(type: unknown) rather "
      'than crashing',
      setUp: () {
        when(
          () => generateTextUseCase(
            inputText: 'New arrivals',
            inputLanguage: InputLanguage.en,
            platform: ContentPlatform.instagram,
            brandKitId: 'brand-kit-1',
          ),
        ).thenAnswer(
          (_) async => const Result.err(
            UnexpectedFailure('Something went wrong. Please try again.'),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(event),
      expect: () => [
        const GenerationInProgress(),
        const GenerationFailure(
          ApiFailure(
            type: ApiErrorType.unknown,
            message: 'Something went wrong. Please try again.',
          ),
        ),
      ],
    );

    blocTest<GenerationBloc, GenerationState>(
      'droppable transformer: a second GenerationRequested fired while '
      'the first is still in flight is dropped, not queued or run '
      'concurrently — the structural fix for a double-tap on Generate '
      '(and, unlike a simple UI double-tap bug, for double-consuming a '
      "user's quota)",
      setUp: () {
        when(
          () => generateTextUseCase(
            inputText: 'New arrivals',
            inputLanguage: InputLanguage.en,
            platform: ContentPlatform.instagram,
            brandKitId: 'brand-kit-1',
          ),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return const Result.ok(result);
        });
      },
      build: buildBloc,
      act: (bloc) {
        bloc
          ..add(event)
          ..add(event);
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const GenerationInProgress(),
        const GenerationSuccess(result),
      ],
      verify: (_) {
        // Exactly one call reached the use case, not two.
        verify(
          () => generateTextUseCase(
            inputText: 'New arrivals',
            inputLanguage: InputLanguage.en,
            platform: ContentPlatform.instagram,
            brandKitId: 'brand-kit-1',
          ),
        ).called(1);
        // Brand kit resolution likewise happened once per accepted event,
        // not once per fired event.
        verify(getBrandKitUseCase.call).called(1);
      },
    );
  });
}
