import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/l10n/locale_cubit.dart';
import 'package:kelal_studio/core/router/app_router.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/theme/theme_cubit.dart';
import 'package:kelal_studio/features/auth/domain/repositories/auth_repository.dart';
import 'package:kelal_studio/features/auth/domain/usecases/login_usecase.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/login_bloc.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/get_brand_kit_usecase.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/update_brand_kit_usecase.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/upload_brand_logo_usecase.dart';
import 'package:kelal_studio/features/brand_kit/presentation/bloc/brand_kit_bloc.dart';
import 'package:kelal_studio/features/generation/domain/usecases/decode_generated_image_usecase.dart';
import 'package:kelal_studio/features/generation/domain/usecases/generate_image_usecase.dart';
import 'package:kelal_studio/features/generation/domain/usecases/generate_text_usecase.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/generation_bloc.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/image_generation_bloc.dart';
import 'package:kelal_studio/features/quota/domain/entities/quota.dart';
import 'package:kelal_studio/features/quota/domain/usecases/get_quota_usecase.dart';
import 'package:kelal_studio/features/quota/presentation/bloc/quota_bloc.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockGetBrandKitUseCase extends Mock implements GetBrandKitUseCase {}

class MockUpdateBrandKitUseCase extends Mock implements UpdateBrandKitUseCase {}

class MockUploadBrandLogoUseCase extends Mock
    implements UploadBrandLogoUseCase {}

class MockGetQuotaUseCase extends Mock implements GetQuotaUseCase {}

class MockGenerateTextUseCase extends Mock implements GenerateTextUseCase {}

class MockGenerateImageUseCase extends Mock implements GenerateImageUseCase {}

class MockDecodeGeneratedImageUseCase extends Mock
    implements DecodeGeneratedImageUseCase {}

/// Minimal in-memory [Storage] so the [HydratedCubit]s pulled in via
/// `LoginPage` (`ThemeCubit`/`LocaleCubit`) can be constructed without
/// touching the filesystem — mirrors
/// test/features/auth/presentation/pages/login_page_test.dart.
class _InMemoryStorage implements Storage {
  final _data = <String, dynamic>{};

  @override
  dynamic read(String key) => _data[key];

  @override
  Future<void> write(String key, dynamic value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<void> close() async {}
}

void main() {
  group('authRedirect', () {
    test('unresolved auth state (null) never redirects', () {
      expect(
        authRedirect(isAuthenticated: null, matchedLocation: '/login'),
        isNull,
      );
      expect(
        authRedirect(isAuthenticated: null, matchedLocation: '/compose'),
        isNull,
      );
    });

    test(
      'an unauthenticated user anywhere but /login is redirected to /login',
      () {
        expect(
          authRedirect(isAuthenticated: false, matchedLocation: '/compose'),
          '/login',
        );
        expect(
          authRedirect(isAuthenticated: false, matchedLocation: '/settings'),
          '/login',
        );
      },
    );

    test('an unauthenticated user already headed to /login is left alone', () {
      expect(
        authRedirect(isAuthenticated: false, matchedLocation: '/login'),
        isNull,
      );
    });

    test(
      'an authenticated user on /login is redirected to the home branch',
      () {
        expect(
          authRedirect(isAuthenticated: true, matchedLocation: '/login'),
          '/compose',
        );
      },
    );

    test('an authenticated user elsewhere is left alone', () {
      expect(
        authRedirect(isAuthenticated: true, matchedLocation: '/drafts'),
        isNull,
      );
    });
  });

  group('AppRouter navigation', () {
    late StreamController<bool> authController;
    late MockAuthRepository authRepository;

    setUpAll(() {
      HydratedBloc.storage = _InMemoryStorage();
    });

    setUp(() {
      authController = StreamController<bool>.broadcast();
      authRepository = MockAuthRepository();
      when(
        () => authRepository.watchIsAuthenticated(),
      ).thenAnswer((_) => authController.stream);
      // Verified by default so these navigation-focused tests don't
      // incidentally also assert on EmailVerificationGate's banner — that
      // behavior has its own dedicated test suite (see
      // test/features/auth/presentation/widgets/email_verification_gate_test.dart).
      when(
        () => authRepository.watchEmailVerified(),
      ).thenAnswer((_) => Stream.value(true));

      // EmailVerificationGate (mounted on the Compose branch) and
      // BrandKitPage (Brand branch) resolve dependencies via getIt
      // directly, same as LoginPage does for LoginBloc. SettingsPage
      // (Settings branch) only reads ThemeCubit/LocaleCubit from context —
      // both provided by wrap()'s MultiBlocProvider — so it needs no getIt
      // registration.
      final getBrandKitUseCase = MockGetBrandKitUseCase();
      when(getBrandKitUseCase.call).thenAnswer(
        (_) async => Result.ok(
          BrandKit(
            id: 'brand-kit-1',
            brandName: 'Demo Business',
            logoAssetId: null,
            primaryColorHex: '#855312',
            secondaryColorHex: '#C6821F',
            toneOfVoice: '',
            contactInfo: '',
            updatedAt: DateTime.utc(2026),
          ),
        ),
      );

      // ComposerPage (also mounted on the Compose branch, inside
      // EmailVerificationGate) resolves GenerationBloc via getIt the same
      // way — it needs its own GetBrandKitUseCase mock instance (composer
      // and brand-kit each get their own BrandKitBloc/GenerationBloc, per
      // getIt's `registerFactory` semantics), stubbed identically to the
      // one above purely so ComposerPage's own brand-kit-id resolution
      // step (see GenerationBloc's doc comment) doesn't hang on an
      // unstubbed mock; these navigation-focused tests never actually
      // trigger a generation call.
      final composerGetBrandKitUseCase = MockGetBrandKitUseCase();
      when(composerGetBrandKitUseCase.call).thenAnswer(
        (_) async => Result.ok(
          BrandKit(
            id: 'brand-kit-1',
            brandName: 'Demo Business',
            logoAssetId: null,
            primaryColorHex: '#855312',
            secondaryColorHex: '#C6821F',
            toneOfVoice: '',
            contactInfo: '',
            updatedAt: DateTime.utc(2026),
          ),
        ),
      );

      // QuotaStatusBadge (also mounted on the Compose branch, alongside
      // EmailVerificationGate — see app_router.dart) resolves QuotaBloc via
      // getIt the same way.
      final getQuotaUseCase = MockGetQuotaUseCase();
      when(getQuotaUseCase.call).thenAnswer(
        (_) async => Result.ok(
          Quota(
            textCallsUsed: 3,
            textCallsLimit: 10,
            imageCallsUsed: 1,
            imageCallsLimit: 5,
            resetsAt: DateTime.utc(2026, 1, 1, 18),
          ),
        ),
      );

      getIt
        ..registerFactory<LoginBloc>(() => LoginBloc(MockLoginUseCase()))
        ..registerLazySingleton<AuthRepository>(() => authRepository)
        ..registerFactory<BrandKitBloc>(
          () => BrandKitBloc(
            getBrandKitUseCase,
            MockUpdateBrandKitUseCase(),
            MockUploadBrandLogoUseCase(),
          ),
        )
        ..registerFactory<QuotaBloc>(() => QuotaBloc(getQuotaUseCase))
        ..registerFactory<GenerationBloc>(
          () => GenerationBloc(
            MockGenerateTextUseCase(),
            composerGetBrandKitUseCase,
          ),
        )
        // ComposerPage also resolves ImageGenerationBloc via getIt
        // (feat/render-engine-canvas-editor) — same reasoning as
        // GenerationBloc above: needed purely so ComposerPage's
        // MultiBlocProvider doesn't throw a "not registered" error on
        // build, these navigation tests never trigger an actual image
        // generation call.
        ..registerFactory<ImageGenerationBloc>(
          () => ImageGenerationBloc(
            MockGenerateImageUseCase(),
            composerGetBrandKitUseCase,
            MockDecodeGeneratedImageUseCase(),
          ),
        );
    });

    tearDown(() async {
      await authController.close();
      await getIt.reset();
    });

    Widget wrap(AppRouter router) {
      return MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeCubit()),
          BlocProvider(create: (_) => LocaleCubit()),
        ],
        child: MaterialApp.router(
          routerConfig: router.config,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          supportedLocales: LocaleCubit.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      );
    }

    testWidgets('starts unauthenticated -> lands on /login', (tester) async {
      final router = AppRouter(authRepository);
      await tester.pumpWidget(wrap(router));
      authController.add(false);
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets(
      'an authenticated stream emission navigates away from /login into '
      'the shell, and tapping each BottomNavBar item switches to the '
      'corresponding placeholder page',
      (tester) async {
        final router = AppRouter(authRepository);
        await tester.pumpWidget(wrap(router));

        authController.add(true);
        await tester.pumpAndSettle();

        expect(find.text('Sign in'), findsNothing);
        expect(find.widgetWithText(AppBar, 'Compose'), findsOneWidget);
        // "Coming soon" was ComposerPage's placeholder predecessor on this
        // route (see app_router.dart) — the real composer form is here
        // now, "Drafts"/"Settings" below are still bare ComingSoonPages.
        expect(
          find.byKey(const Key('composer_generate_button')),
          findsOneWidget,
        );

        await tester.tap(find.text('Drafts'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Drafts'), findsOneWidget);

        await tester.tap(find.text('Brand'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Brand'), findsOneWidget);

        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
      },
    );

    testWidgets('logging out while inside the shell redirects back to /login', (
      tester,
    ) async {
      final router = AppRouter(authRepository);
      await tester.pumpWidget(wrap(router));

      authController.add(true);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Compose'), findsOneWidget);

      authController.add(false);
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets(
      'landing on /canvas-editor without a CanvasEditorPageArgs extra (e.g. '
      'go_router state restored after process death, which drops extra) '
      'redirects to Compose instead of crashing on the unguarded cast',
      (tester) async {
        final router = AppRouter(authRepository);
        await tester.pumpWidget(wrap(router));

        authController.add(true);
        await tester.pumpAndSettle();

        router.config.go('/canvas-editor');
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.widgetWithText(AppBar, 'Compose'), findsOneWidget);
      },
    );

    testWidgets(
      'landing on /export without an ExportPageArgs extra redirects to '
      'Compose instead of crashing on the unguarded cast — same '
      'process-death `extra`-drop guard as /canvas-editor',
      (tester) async {
        final router = AppRouter(authRepository);
        await tester.pumpWidget(wrap(router));

        authController.add(true);
        await tester.pumpAndSettle();

        router.config.go('/export');
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.widgetWithText(AppBar, 'Compose'), findsOneWidget);
      },
    );
  });
}
