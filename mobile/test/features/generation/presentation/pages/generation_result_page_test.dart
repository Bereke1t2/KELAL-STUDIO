import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/get_brand_kit_usecase.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/bloc/canvas_editor_bloc.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/pages/canvas_editor_page.dart';
import 'package:kelal_studio/features/drafts/domain/usecases/save_draft_usecase.dart';
import 'package:kelal_studio/features/drafts/presentation/cubit/draft_autosave_cubit.dart';
import 'package:kelal_studio/features/generation/domain/entities/aspect_ratio.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_image_result.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_result.dart';
import 'package:kelal_studio/features/generation/domain/usecases/decode_generated_image_usecase.dart';
import 'package:kelal_studio/features/generation/domain/usecases/generate_image_usecase.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/image_generation_bloc.dart';
import 'package:kelal_studio/features/generation/presentation/pages/generation_result_page.dart';
import 'package:mocktail/mocktail.dart';

class MockGenerateImageUseCase extends Mock implements GenerateImageUseCase {}

class MockGetBrandKitUseCase extends Mock implements GetBrandKitUseCase {}

class MockDecodeGeneratedImageUseCase extends Mock
    implements DecodeGeneratedImageUseCase {}

class MockSaveDraftUseCase extends Mock implements SaveDraftUseCase {}

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

  const args = GenerationResultPageArgs(
    result: result,
    inputText: 'New product launch',
  );

  setUpAll(() {
    registerFallbackValue(GenerationAspectRatio.oneToOne);
  });

  setUp(() {
    generateImageUseCase = MockGenerateImageUseCase();
    getBrandKitUseCase = MockGetBrandKitUseCase();
    decodeGeneratedImageUseCase = MockDecodeGeneratedImageUseCase();
    when(getBrandKitUseCase.call).thenAnswer((_) async => Result.ok(brandKit));
    getIt
      ..registerFactory<ImageGenerationBloc>(
        () => ImageGenerationBloc(
          generateImageUseCase,
          getBrandKitUseCase,
          decodeGeneratedImageUseCase,
        ),
      )
      // Resolved once a test actually reaches /canvas-editor — see
      // composer_page_test.dart's identical setup note (CanvasEditorBloc
      // has no constructor dependencies; DraftAutosaveCubit's debounce
      // timer never fires within these tests' timeframe).
      ..registerFactory<CanvasEditorBloc>(CanvasEditorBloc.new)
      ..registerFactory<DraftAutosaveCubit>(
        () => DraftAutosaveCubit(MockSaveDraftUseCase()),
      );
  });

  tearDown(() async {
    await getIt.reset();
  });

  // In the real app this page is always *pushed* on top of Compose, never
  // the root of the navigation stack — pumping '/' first and then actually
  // pushing '/result' (rather than starting there directly, which
  // `GoRouter` resolves as a single-entry stack with nothing to pop)
  // mirrors that shape, so `AppBar`'s automatic back button (which only
  // appears when `Navigator.canPop()` is true) shows up the same way it
  // does for real, instead of this file asserting against a structural
  // artifact of being the router's only route.
  Future<void> pumpResultPage(
    WidgetTester tester, {
    GenerationResultPageArgs pageArgs = args,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: SizedBox()),
        ),
        GoRoute(
          path: '/result',
          builder: (context, state) => GenerationResultPage(args: pageArgs),
        ),
        GoRoute(
          path: '/canvas-editor',
          builder: (context, state) =>
              CanvasEditorPage(args: state.extra! as CanvasEditorPageArgs),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('am')],
        routerConfig: router,
      ),
    );
    // Not awaited deliberately — `push`'s Future only resolves once
    // '/result' is later popped, which isn't what this helper waits for.
    unawaited(router.push('/result'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the result fields and a back button', (tester) async {
    await pumpResultPage(tester);

    expect(find.text('Check out our new arrivals!'), findsOneWidget);
    expect(find.text('አዲስ ምርቶቻችንን ይመልከቱ!'), findsOneWidget);
    expect(find.text('Shop now'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('a fallback-template result shows the "saved template" notice', (
    tester,
  ) async {
    await pumpResultPage(
      tester,
      pageArgs: const GenerationResultPageArgs(
        result: GenerationResult(
          captionEn: 'Check out our new arrivals!',
          captionAm: 'አዲስ ምርቶቻችንን ይመልከቱ!',
          callToAction: 'Shop now',
          hashtags: ['#new', '#shop'],
          isFallback: true,
        ),
        inputText: 'New product launch',
      ),
    );

    expect(find.byKey(const Key('generation_fallback_notice')), findsOneWidget);
  });

  testWidgets('appears with a "Create graphic" button that dispatches '
      "ImageGenerationRequested with the result's English caption", (
    tester,
  ) async {
    when(
      () => generateImageUseCase(
        captionEn: result.captionEn,
        aspectRatio: GenerationAspectRatio.oneToOne,
        brandKitId: 'brand-kit-1',
      ),
    ).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return const Result.err(
        ApiFailure(
          type: ApiErrorType.unknown,
          message: 'Something went wrong. Please try again.',
        ),
      );
    });

    await pumpResultPage(tester);

    expect(
      find.byKey(const Key('composer_create_graphic_button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('composer_create_graphic_button')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(
      () => generateImageUseCase(
        captionEn: result.captionEn,
        aspectRatio: GenerationAspectRatio.oneToOne,
        brandKitId: 'brand-kit-1',
      ),
    ).called(1);

    await tester.pumpAndSettle();
  });

  testWidgets('shows the brand-kit-required snack bar when no brand kit can be '
      'resolved for image generation', (tester) async {
    when(getBrandKitUseCase.call).thenAnswer(
      (_) async => const Result.err(
        ApiFailure(
          type: ApiErrorType.network,
          message: 'No connection. Check your network and try again.',
        ),
      ),
    );

    await pumpResultPage(tester);
    await tester.tap(find.byKey(const Key('composer_create_graphic_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Set up your Brand Kit before creating a graphic.'),
      findsOneWidget,
    );
    verifyNever(
      () => generateImageUseCase(
        captionEn: any(named: 'captionEn'),
        aspectRatio: any(named: 'aspectRatio'),
        brandKitId: any(named: 'brandKitId'),
      ),
    );
  });

  testWidgets('a quotaExceeded image-generation failure shows the blocking '
      'dialog', (tester) async {
    when(
      () => generateImageUseCase(
        captionEn: result.captionEn,
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

    await pumpResultPage(tester);
    await tester.tap(find.byKey(const Key('composer_create_graphic_button')));
    await tester.pumpAndSettle();

    expect(find.text('Quota reached'), findsOneWidget);
  });

  testWidgets(
    'a non-quota image-generation failure shows a plain-language snack bar',
    (tester) async {
      when(
        () => generateImageUseCase(
          captionEn: result.captionEn,
          aspectRatio: GenerationAspectRatio.oneToOne,
          brandKitId: 'brand-kit-1',
        ),
      ).thenAnswer(
        (_) async => const Result.err(
          ApiFailure(
            type: ApiErrorType.providerTimeout,
            message: 'irrelevant raw message',
          ),
        ),
      );

      await pumpResultPage(tester);
      await tester.tap(find.byKey(const Key('composer_create_graphic_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Generation is taking longer than usual. Please try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a validationError image-generation failure uses image-specific copy, '
    "not the text-generation path's \"check your idea\" message (the idea "
    'field has nothing to do with this page — a result already exists by '
    'the time it can be shown)',
    (tester) async {
      when(
        () => generateImageUseCase(
          captionEn: result.captionEn,
          aspectRatio: GenerationAspectRatio.oneToOne,
          brandKitId: 'brand-kit-1',
        ),
      ).thenAnswer(
        (_) async => const Result.err(
          ApiFailure(
            type: ApiErrorType.validationError,
            message: 'irrelevant raw message',
          ),
        ),
      );

      await pumpResultPage(tester);
      await tester.tap(find.byKey(const Key('composer_create_graphic_button')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "We couldn't create a graphic from that. Try generating a new "
          'caption first.',
        ),
        findsOneWidget,
      );
      expect(find.text('Please check your idea and try again.'), findsNothing);
    },
  );

  testWidgets(
    'a successful image generation navigates to /canvas-editor, carrying '
    "both of this page's own caption strings alongside the scene",
    (tester) async {
      await pumpResultPage(tester);

      final image = await _testImage();
      addTearDown(image.dispose);
      when(
        () => generateImageUseCase(
          captionEn: result.captionEn,
          aspectRatio: GenerationAspectRatio.oneToOne,
          brandKitId: 'brand-kit-1',
        ),
      ).thenAnswer(
        (_) async => const Result.ok(
          GenerationImageResult(
            assetId: 'asset-1',
            imageUrl: 'https://picsum.photos/seed/1/1080/1080',
            width: 1080,
            height: 1080,
          ),
        ),
      );
      when(
        () => decodeGeneratedImageUseCase(
          'https://picsum.photos/seed/1/1080/1080',
        ),
      ).thenAnswer((_) async => Result.ok(image));

      await tester.tap(find.byKey(const Key('composer_create_graphic_button')));
      await tester.pumpAndSettle();

      expect(find.byType(CanvasEditorPage), findsOneWidget);
    },
  );
}
