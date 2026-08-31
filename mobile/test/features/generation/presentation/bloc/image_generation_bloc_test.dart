import 'dart:ui' as ui;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/get_brand_kit_usecase.dart';
import 'package:kelal_studio/features/generation/domain/entities/aspect_ratio.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_image_result.dart';
import 'package:kelal_studio/features/generation/domain/usecases/decode_generated_image_usecase.dart';
import 'package:kelal_studio/features/generation/domain/usecases/generate_image_usecase.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/image_generation_bloc.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/image_generation_event.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/image_generation_state.dart';
import 'package:mocktail/mocktail.dart';

class MockGenerateImageUseCase extends Mock implements GenerateImageUseCase {}

class MockGetBrandKitUseCase extends Mock implements GetBrandKitUseCase {}

class MockDecodeGeneratedImageUseCase extends Mock
    implements DecodeGeneratedImageUseCase {}

Future<ui.Image> _testImage() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 4, 4),
    Paint()..color = const Color(0xFF00FF00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(4, 4);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGenerateImageUseCase generateImageUseCase;
  late MockGetBrandKitUseCase getBrandKitUseCase;
  late MockDecodeGeneratedImageUseCase decodeGeneratedImageUseCase;
  late ui.Image decodedImage;

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

  const imageResult = GenerationImageResult(
    assetId: 'asset-1',
    imageUrl: 'https://picsum.photos/seed/1/1080/1080',
    width: 1080,
    height: 1080,
  );

  const event = ImageGenerationRequested(
    captionEn: 'Check out our new arrivals!',
    aspectRatio: GenerationAspectRatio.oneToOne,
  );

  setUpAll(() {
    // Needed for the `any(named: ...)` matcher in the `verifyNever` call
    // below — mocktail requires a registered fallback for every type
    // `any()` is used with.
    registerFallbackValue(GenerationAspectRatio.oneToOne);
  });

  setUp(() async {
    decodedImage = await _testImage();
    generateImageUseCase = MockGenerateImageUseCase();
    getBrandKitUseCase = MockGetBrandKitUseCase();
    decodeGeneratedImageUseCase = MockDecodeGeneratedImageUseCase();
    when(getBrandKitUseCase.call).thenAnswer((_) async => Result.ok(brandKit));
  });

  tearDown(() {
    decodedImage.dispose();
  });

  ImageGenerationBloc buildBloc() => ImageGenerationBloc(
    generateImageUseCase,
    getBrandKitUseCase,
    decodeGeneratedImageUseCase,
  );

  group('ImageGenerationRequested', () {
    blocTest<ImageGenerationBloc, ImageGenerationState>(
      'emits [InProgress, BrandKitRequired] and never calls '
      'GenerateImageUseCase when no brand kit can be resolved — unlike '
      'GenerationBloc, brand_kit_id is required on the wire here',
      setUp: () {
        when(getBrandKitUseCase.call).thenAnswer(
          (_) async => const Result.err(
            ApiFailure(
              type: ApiErrorType.network,
              message: 'No connection. Check your network and try again.',
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(event),
      expect: () => [
        const ImageGenerationInProgress(),
        const ImageGenerationBrandKitRequired(),
      ],
      verify: (_) {
        verifyNever(
          () => generateImageUseCase(
            captionEn: any(named: 'captionEn'),
            aspectRatio: any(named: 'aspectRatio'),
            brandKitId: any(named: 'brandKitId'),
          ),
        );
      },
    );

    blocTest<ImageGenerationBloc, ImageGenerationState>(
      'emits [InProgress, Success] with a CanvasScene sized to the real '
      'GenerateImageResponse width/height, not a hardcoded aspect-ratio '
      'guess',
      setUp: () {
        when(
          () => generateImageUseCase(
            captionEn: 'Check out our new arrivals!',
            aspectRatio: GenerationAspectRatio.oneToOne,
            brandKitId: 'brand-kit-1',
          ),
        ).thenAnswer((_) async => const Result.ok(imageResult));
        when(
          () => decodeGeneratedImageUseCase(
            'https://picsum.photos/seed/1/1080/1080',
          ),
        ).thenAnswer((_) async => Result.ok(decodedImage));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(event),
      expect: () => [
        const ImageGenerationInProgress(),
        isA<ImageGenerationSuccess>()
            .having((s) => s.result, 'result', imageResult)
            .having(
              (s) => s.scene.canvasSize,
              'scene.canvasSize',
              const Size(1080, 1080),
            )
            .having(
              (s) => s.scene.backgroundImage,
              'scene.backgroundImage',
              same(decodedImage),
            )
            .having((s) => s.scene.logo, 'scene.logo', isNull),
      ],
    );

    blocTest<ImageGenerationBloc, ImageGenerationState>(
      'emits [InProgress, Failure] when /generate/image itself fails, '
      'never reaching the decode step',
      setUp: () {
        when(
          () => generateImageUseCase(
            captionEn: 'Check out our new arrivals!',
            aspectRatio: GenerationAspectRatio.oneToOne,
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
      },
      build: buildBloc,
      act: (bloc) => bloc.add(event),
      expect: () => [
        const ImageGenerationInProgress(),
        const ImageGenerationFailure(
          ApiFailure(
            type: ApiErrorType.quotaExceeded,
            message: "You've used today's generation quota. It resets soon.",
          ),
        ),
      ],
      verify: (_) {
        verifyNever(() => decodeGeneratedImageUseCase(any()));
      },
    );

    blocTest<ImageGenerationBloc, ImageGenerationState>(
      'emits [InProgress, Failure] when generation succeeds but decoding '
      'the returned image fails',
      setUp: () {
        when(
          () => generateImageUseCase(
            captionEn: 'Check out our new arrivals!',
            aspectRatio: GenerationAspectRatio.oneToOne,
            brandKitId: 'brand-kit-1',
          ),
        ).thenAnswer((_) async => const Result.ok(imageResult));
        when(
          () => decodeGeneratedImageUseCase(
            'https://picsum.photos/seed/1/1080/1080',
          ),
        ).thenAnswer(
          (_) async => const Result.err(
            UnexpectedFailure("Couldn't load the generated image."),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(event),
      expect: () => [
        const ImageGenerationInProgress(),
        const ImageGenerationFailure(
          ApiFailure(
            type: ApiErrorType.unknown,
            message: "Couldn't load the generated image.",
          ),
        ),
      ],
    );

    blocTest<ImageGenerationBloc, ImageGenerationState>(
      'droppable transformer: a second ImageGenerationRequested fired '
      'while the first is still mid-flight (including mid-decode) is '
      'dropped, not queued or run concurrently',
      setUp: () {
        when(
          () => generateImageUseCase(
            captionEn: 'Check out our new arrivals!',
            aspectRatio: GenerationAspectRatio.oneToOne,
            brandKitId: 'brand-kit-1',
          ),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return const Result.ok(imageResult);
        });
        when(
          () => decodeGeneratedImageUseCase(
            'https://picsum.photos/seed/1/1080/1080',
          ),
        ).thenAnswer((_) async => Result.ok(decodedImage));
      },
      build: buildBloc,
      act: (bloc) {
        bloc
          ..add(event)
          ..add(event);
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const ImageGenerationInProgress(),
        isA<ImageGenerationSuccess>(),
      ],
      verify: (_) {
        verify(
          () => generateImageUseCase(
            captionEn: 'Check out our new arrivals!',
            aspectRatio: GenerationAspectRatio.oneToOne,
            brandKitId: 'brand-kit-1',
          ),
        ).called(1);
      },
    );
  });
}
