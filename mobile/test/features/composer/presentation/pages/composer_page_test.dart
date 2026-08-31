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
import 'package:kelal_studio/features/composer/presentation/pages/composer_page.dart';
import 'package:kelal_studio/features/generation/domain/entities/content_platform.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_result.dart';
import 'package:kelal_studio/features/generation/domain/entities/input_language.dart';
import 'package:kelal_studio/features/generation/domain/usecases/generate_text_usecase.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/generation_bloc.dart';
import 'package:kelal_studio/features/generation/presentation/pages/generation_result_page.dart';
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

  setUpAll(() {
    // Needed for the `any(named: ...)` matchers in
    // `verifyNever(() => generateTextUseCase(...))` below — mocktail
    // requires a registered fallback for every type `any()` is used with.
    registerFallbackValue(InputLanguage.en);
    registerFallbackValue(ContentPlatform.instagram);
  });

  setUp(() {
    generateTextUseCase = MockGenerateTextUseCase();
    getBrandKitUseCase = MockGetBrandKitUseCase();
    when(getBrandKitUseCase.call).thenAnswer((_) async => Result.ok(brandKit));
    getIt.registerFactory<GenerationBloc>(
      () => GenerationBloc(generateTextUseCase, getBrandKitUseCase),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  // A real GoRouter, not a bare Scaffold — ComposerPage now navigates to
  // '/generation-result' on a successful generation (see its own
  // BlocListener) rather than rendering the result inline, so
  // `context.push` needs a real GoRouter ancestor (same reasoning
  // register_page_test.dart's wrap() upgrade already established). The
  // '/generation-result' route is a lightweight stub, not the real
  // GenerationResultPage — this file's job is proving ComposerPage
  // navigates with the *right* GenerationResultPageArgs, not re-testing
  // GenerationResultPage's own rendering (see
  // generation_result_page_test.dart for that).
  GenerationResultPageArgs? pushedArgs;
  Widget wrap() {
    pushedArgs = null;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: ComposerPage()),
        ),
        GoRoute(
          path: '/generation-result',
          builder: (context, state) {
            pushedArgs = state.extra! as GenerationResultPageArgs;
            return const Scaffold(body: Text('generation_result_page_stub'));
          },
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('am')],
      routerConfig: router,
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
    "navigates to '/generation-result' carrying the result and the "
    'snapshotted idea text',
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

      expect(find.text('generation_result_page_stub'), findsOneWidget);
      expect(pushedArgs, isNotNull);
      expect(pushedArgs!.result, result);
      expect(pushedArgs!.inputText, 'New product launch');
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
    'banner, without navigating away',
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
      expect(find.text('generation_result_page_stub'), findsNothing);
      expect(pushedArgs, isNull);
    },
  );

  testWidgets(
    'a quotaExceeded failure shows the blocking dialog, not the inline '
    'error banner, without navigating away',
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
      expect(pushedArgs, isNull);
    },
  );
}
