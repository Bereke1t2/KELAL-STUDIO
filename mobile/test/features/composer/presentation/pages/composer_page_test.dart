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
import 'package:kelal_studio/features/composer/presentation/pages/composer_page.dart';
import 'package:kelal_studio/features/generation/domain/entities/aspect_ratio.dart';
import 'package:kelal_studio/features/generation/domain/entities/content_platform.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_image_result.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_result.dart';
import 'package:kelal_studio/features/generation/domain/entities/input_language.dart';
import 'package:kelal_studio/features/generation/domain/usecases/decode_generated_image_usecase.dart';
import 'package:kelal_studio/features/generation/domain/usecases/generate_image_usecase.dart';
import 'package:kelal_studio/features/generation/domain/usecases/generate_text_usecase.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/generation_bloc.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/image_generation_bloc.dart';
import 'package:mocktail/mocktail.dart';

class MockGenerateTextUseCase extends Mock implements GenerateTextUseCase {}

class MockGenerateImageUseCase extends Mock implements GenerateImageUseCase {}

class MockDecodeGeneratedImageUseCase extends Mock
    implements DecodeGeneratedImageUseCase {}

class MockGetBrandKitUseCase extends Mock implements GetBrandKitUseCase {}

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

  late MockGenerateTextUseCase generateTextUseCase;
  late MockGenerateImageUseCase generateImageUseCase;
  late MockDecodeGeneratedImageUseCase decodeGeneratedImageUseCase;
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

  setUpAll(() {
    // Needed for the `any(named: ...)` matchers in
    // `verifyNever(() => generateTextUseCase(...))` below — mocktail
    // requires a registered fallback for every type `any()` is used with.
    registerFallbackValue(InputLanguage.en);
    registerFallbackValue(ContentPlatform.instagram);
    registerFallbackValue(GenerationAspectRatio.oneToOne);
  });

  setUp(() {
    generateTextUseCase = MockGenerateTextUseCase();
    generateImageUseCase = MockGenerateImageUseCase();
    decodeGeneratedImageUseCase = MockDecodeGeneratedImageUseCase();
    getBrandKitUseCase = MockGetBrandKitUseCase();
    when(getBrandKitUseCase.call).thenAnswer((_) async => Result.ok(brandKit));
    getIt
      ..registerFactory<GenerationBloc>(
        () => GenerationBloc(generateTextUseCase, getBrandKitUseCase),
      )
      ..registerFactory<ImageGenerationBloc>(
        () => ImageGenerationBloc(
          generateImageUseCase,
          getBrandKitUseCase,
          decodeGeneratedImageUseCase,
        ),
      )
      // Resolved by CanvasEditorPage once the "navigates to /canvas-editor"
      // test actually reaches that route — has no constructor dependencies
      // (see CanvasEditorBloc's own doc comment), so no mock is needed.
      ..registerFactory<CanvasEditorBloc>(CanvasEditorBloc.new);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget wrap() {
    return MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('am')],
      home: const Scaffold(body: ComposerPage()),
    );
  }

  testWidgets(
    'shows the idea field, language/platform toggles, and Generate button',
    (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.byKey(const Key('composer_idea_field')), findsOneWidget);
      expect(find.byKey(const Key('composer_language_toggle')), findsOneWidget);
      expect(find.byKey(const Key('composer_platform_toggle')), findsOneWidget);
      expect(find.byKey(const Key('composer_generate_button')), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('TikTok'), findsOneWidget);
      expect(find.text('Telegram'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Generate with an empty idea shows a local validation error '
    'and never calls GenerateTextUseCase',
    (tester) async {
      await tester.pumpWidget(wrap());

      await tester.tap(find.byKey(const Key('composer_generate_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter an idea to generate content for.'),
        findsOneWidget,
      );
      verifyNever(
        () => generateTextUseCase(
          inputText: any(named: 'inputText'),
          inputLanguage: any(named: 'inputLanguage'),
          platform: any(named: 'platform'),
          brandKitId: any(named: 'brandKitId'),
        ),
      );
    },
  );

  testWidgets(
    'a successful generation shows a loading state on the button, then '
    'the result fields',
    (tester) async {
      when(
        () => generateTextUseCase(
          inputText: 'New product launch',
          inputLanguage: InputLanguage.auto,
          platform: ContentPlatform.instagram,
          brandKitId: 'brand-kit-1',
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return const Result.ok(result);
      });

      await tester.pumpWidget(wrap());
      await tester.enterText(
        find.byKey(const Key('composer_idea_field')),
        'New product launch',
      );
      await tester.tap(find.byKey(const Key('composer_generate_button')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Check out our new arrivals!'), findsOneWidget);
      expect(find.text('አዲስ ምርቶቻችንን ይመልከቱ!'), findsOneWidget);
      expect(find.text('Shop now'), findsOneWidget);
    },
  );

  testWidgets(
    'switching the platform toggle changes what GenerateTextUseCase is '
    'called with',
    (tester) async {
      when(
        () => generateTextUseCase(
          inputText: 'New product launch',
          inputLanguage: InputLanguage.auto,
          platform: ContentPlatform.telegram,
          brandKitId: 'brand-kit-1',
        ),
      ).thenAnswer((_) async => const Result.ok(result));

      await tester.pumpWidget(wrap());
      await tester.enterText(
        find.byKey(const Key('composer_idea_field')),
        'New product launch',
      );
      await tester.tap(find.text('Telegram'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('composer_generate_button')));
      await tester.pumpAndSettle();

      verify(
        () => generateTextUseCase(
          inputText: 'New product launch',
          inputLanguage: InputLanguage.auto,
          platform: ContentPlatform.telegram,
          brandKitId: 'brand-kit-1',
        ),
      ).called(1);
    },
  );

  testWidgets(
    'a non-quota generation failure shows a plain-language inline error '
    'banner',
    (tester) async {
      when(
        () => generateTextUseCase(
          inputText: 'New product launch',
          inputLanguage: InputLanguage.auto,
          platform: ContentPlatform.instagram,
          brandKitId: 'brand-kit-1',
        ),
      ).thenAnswer(
        (_) async => const Result.err(
          ApiFailure(
            type: ApiErrorType.validationError,
            message: 'Please check your input and try again.',
          ),
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.enterText(
        find.byKey(const Key('composer_idea_field')),
        'New product launch',
      );
      await tester.tap(find.byKey(const Key('composer_generate_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('composer_generation_error_banner')),
        findsOneWidget,
      );
      expect(
        find.text('Please check your idea and try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a quotaExceeded failure shows the blocking dialog, not the inline '
    'error banner',
    (tester) async {
      when(
        () => generateTextUseCase(
          inputText: 'New product launch',
          inputLanguage: InputLanguage.auto,
          platform: ContentPlatform.instagram,
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

      await tester.pumpWidget(wrap());
      await tester.enterText(
        find.byKey(const Key('composer_idea_field')),
        'New product launch',
      );
      await tester.tap(find.byKey(const Key('composer_generate_button')));
      await tester.pumpAndSettle();

      expect(find.text('Quota reached'), findsOneWidget);
      expect(
        find.byKey(const Key('composer_generation_error_banner')),
        findsNothing,
      );
    },
  );

  testWidgets('a fallback-template result shows the "saved template" notice', (
    tester,
  ) async {
    when(
      () => generateTextUseCase(
        inputText: 'New product launch',
        inputLanguage: InputLanguage.auto,
        platform: ContentPlatform.instagram,
        brandKitId: 'brand-kit-1',
      ),
    ).thenAnswer((_) async => Result.ok(result.copyWith(isFallback: true)));

    await tester.pumpWidget(wrap());
    await tester.enterText(
      find.byKey(const Key('composer_idea_field')),
      'New product launch',
    );
    await tester.tap(find.byKey(const Key('composer_generate_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('generation_fallback_notice')), findsOneWidget);
  });

  Future<void> generateSuccessfully(WidgetTester tester) async {
    when(
      () => generateTextUseCase(
        inputText: 'New product launch',
        inputLanguage: InputLanguage.auto,
        platform: ContentPlatform.instagram,
        brandKitId: 'brand-kit-1',
      ),
    ).thenAnswer((_) async => const Result.ok(result));

    await tester.pumpWidget(wrap());
    await tester.enterText(
      find.byKey(const Key('composer_idea_field')),
      'New product launch',
    );
    await tester.tap(find.byKey(const Key('composer_generate_button')));
    await tester.pumpAndSettle();
    // The result view pushes "Create graphic" below the 800x600 test
    // viewport inside ComposerPage's SingleChildScrollView — scroll it
    // into view so callers can tap it without a hit-test miss.
    await tester.ensureVisible(
      find.byKey(const Key('composer_create_graphic_button')),
    );
  }

  group('Create graphic', () {
    testWidgets('is not shown before a successful text generation', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());

      expect(
        find.byKey(const Key('composer_create_graphic_button')),
        findsNothing,
      );
    });

    testWidgets('appears after a successful generation and dispatches '
        "ImageGenerationRequested with the result's English caption", (
      tester,
    ) async {
      await generateSuccessfully(tester);

      expect(
        find.byKey(const Key('composer_create_graphic_button')),
        findsOneWidget,
      );

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

    testWidgets(
      'shows the brand-kit-required snack bar when no brand kit can be '
      'resolved for image generation',
      (tester) async {
        await generateSuccessfully(tester);

        when(getBrandKitUseCase.call).thenAnswer(
          (_) async => const Result.err(
            ApiFailure(
              type: ApiErrorType.network,
              message: 'No connection. Check your network and try again.',
            ),
          ),
        );

        await tester.tap(
          find.byKey(const Key('composer_create_graphic_button')),
        );
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
      },
    );

    testWidgets(
      'a quotaExceeded image-generation failure shows the blocking dialog',
      (tester) async {
        await generateSuccessfully(tester);

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

        await tester.tap(
          find.byKey(const Key('composer_create_graphic_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Quota reached'), findsOneWidget);
      },
    );

    testWidgets(
      'a non-quota image-generation failure shows a plain-language snack '
      'bar',
      (tester) async {
        await generateSuccessfully(tester);

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

        await tester.tap(
          find.byKey(const Key('composer_create_graphic_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Generation is taking longer than usual. Please try again.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a validationError image-generation failure uses image-specific copy, '
      "not the text-generation path's \"check your idea\" message (the "
      'idea field has already passed validation by this point)',
      (tester) async {
        await generateSuccessfully(tester);

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

        await tester.tap(
          find.byKey(const Key('composer_create_graphic_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            "We couldn't create a graphic from that. Try generating a new "
            'caption first.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Please check your idea and try again.'),
          findsNothing,
        );
      },
    );

    testWidgets('a successful image generation navigates to /canvas-editor, '
        "carrying both of the original GenerationResult's caption strings "
        "alongside the scene (see CanvasEditorPageArgs' doc comment — "
        'ImageGenerationSuccess itself only carries the scene, so the '
        "captions come from _createGraphic's own snapshot instead)", (
      tester,
    ) async {
      CanvasEditorPageArgs? pushedArgs;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: ComposerPage()),
          ),
          GoRoute(
            path: '/canvas-editor',
            builder: (context, state) {
              pushedArgs = state.extra! as CanvasEditorPageArgs;
              return CanvasEditorPage(args: pushedArgs!);
            },
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
      await tester.pumpAndSettle();

      when(
        () => generateTextUseCase(
          inputText: 'New product launch',
          inputLanguage: InputLanguage.auto,
          platform: ContentPlatform.instagram,
          brandKitId: 'brand-kit-1',
        ),
      ).thenAnswer((_) async => const Result.ok(result));
      await tester.enterText(
        find.byKey(const Key('composer_idea_field')),
        'New product launch',
      );
      await tester.tap(find.byKey(const Key('composer_generate_button')));
      await tester.pumpAndSettle();

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

      await tester.ensureVisible(
        find.byKey(const Key('composer_create_graphic_button')),
      );
      await tester.tap(find.byKey(const Key('composer_create_graphic_button')));
      await tester.pumpAndSettle();

      expect(find.byType(CanvasEditorPage), findsOneWidget);
      expect(pushedArgs, isNotNull);
      expect(pushedArgs!.captionEn, result.captionEn);
      expect(pushedArgs!.captionAm, result.captionAm);
    });

    testWidgets(
      're-generating the idea text while a Create-graphic request for the '
      'PREVIOUS result is still in flight does not corrupt the captions '
      'that later reach /canvas-editor — they stay pinned to whichever '
      'result "Create graphic" was actually tapped for, not whatever '
      "GenerationBloc's state happens to be once the image request finally "
      'resolves',
      (tester) async {
        const resultB = GenerationResult(
          captionEn: 'Second idea caption (EN)',
          captionAm: 'ሁለተኛ ሀሳብ መግለጫ',
          callToAction: 'Learn more',
          hashtags: ['#second'],
          isFallback: false,
        );

        CanvasEditorPageArgs? pushedArgs;
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(body: ComposerPage()),
            ),
            GoRoute(
              path: '/canvas-editor',
              builder: (context, state) {
                pushedArgs = state.extra! as CanvasEditorPageArgs;
                return CanvasEditorPage(args: pushedArgs!);
              },
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
        await tester.pumpAndSettle();

        // Generate idea A's text result.
        when(
          () => generateTextUseCase(
            inputText: 'Idea A',
            inputLanguage: InputLanguage.auto,
            platform: ContentPlatform.instagram,
            brandKitId: 'brand-kit-1',
          ),
        ).thenAnswer((_) async => const Result.ok(result));
        await tester.enterText(
          find.byKey(const Key('composer_idea_field')),
          'Idea A',
        );
        await tester.tap(find.byKey(const Key('composer_generate_button')));
        await tester.pumpAndSettle();

        // Tap "Create graphic" for idea A, but hold the image-generation
        // response open via an uncompleted Completer — this is the window
        // a fast text re-generation can land in.
        final image = await _testImage();
        addTearDown(image.dispose);
        final generateImageCompleter =
            Completer<Result<ApiFailure, GenerationImageResult>>();
        when(
          () => generateImageUseCase(
            captionEn: result.captionEn,
            aspectRatio: GenerationAspectRatio.oneToOne,
            brandKitId: 'brand-kit-1',
          ),
        ).thenAnswer((_) => generateImageCompleter.future);

        await tester.ensureVisible(
          find.byKey(const Key('composer_create_graphic_button')),
        );
        await tester.tap(
          find.byKey(const Key('composer_create_graphic_button')),
        );
        await tester.pump();

        // While idea A's image request is still pending, re-generate the
        // idea text as idea B — GenerationBloc is free to accept this
        // (only ImageGenerationBloc's own in-flight request blocks a
        // second *image* request; nothing about a pending image request
        // blocks a new *text* one).
        when(
          () => generateTextUseCase(
            inputText: 'Idea B',
            inputLanguage: InputLanguage.auto,
            platform: ContentPlatform.instagram,
            brandKitId: 'brand-kit-1',
          ),
        ).thenAnswer((_) async => const Result.ok(resultB));
        await tester.enterText(
          find.byKey(const Key('composer_idea_field')),
          'Idea B',
        );
        await tester.tap(find.byKey(const Key('composer_generate_button')));
        // Not pumpAndSettle(): the "Create graphic" button's spinner is
        // still indeterminate here (idea A's image request is
        // deliberately still held open via generateImageCompleter), and an
        // indeterminate CircularProgressIndicator never stops scheduling
        // frames on its own (see PrimaryButton.loadingValue's doc
        // comment) — pumpAndSettle would hang waiting for it regardless of
        // whether idea B's (already-mocked, near-instant) text generation
        // has finished. A few bounded pumps are enough to flush it.
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // GenerationBloc has now moved on to resultB's captions — confirm
        // that actually happened, so this test is exercising the race it
        // claims to.
        expect(find.text(resultB.captionEn), findsOneWidget);

        // Now let idea A's held-open image request resolve.
        when(
          () => decodeGeneratedImageUseCase(
            'https://picsum.photos/seed/a/1080/1080',
          ),
        ).thenAnswer((_) async => Result.ok(image));
        generateImageCompleter.complete(
          const Result.ok(
            GenerationImageResult(
              assetId: 'asset-a',
              imageUrl: 'https://picsum.photos/seed/a/1080/1080',
              width: 1080,
              height: 1080,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CanvasEditorPage), findsOneWidget);
        expect(pushedArgs, isNotNull);
        // Must still be idea A's captions — the ones "Create graphic" was
        // actually tapped for — not idea B's, even though GenerationBloc's
        // current state is resultB by the time this navigation happens.
        expect(pushedArgs!.captionEn, result.captionEn);
        expect(pushedArgs!.captionAm, result.captionAm);
      },
    );
  });
}

extension on GenerationResult {
  GenerationResult copyWith({bool? isFallback}) => GenerationResult(
    captionEn: captionEn,
    captionAm: captionAm,
    callToAction: callToAction,
    hashtags: hashtags,
    isFallback: isFallback ?? this.isFallback,
  );
}
