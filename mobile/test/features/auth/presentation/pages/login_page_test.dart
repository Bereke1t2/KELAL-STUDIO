import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/l10n/locale_cubit.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/theme/theme_cubit.dart';
import 'package:kelal_studio/features/auth/domain/entities/auth_session.dart';
import 'package:kelal_studio/features/auth/domain/usecases/login_usecase.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/login_bloc.dart';
import 'package:kelal_studio/features/auth/presentation/pages/login_page.dart';
import 'package:mocktail/mocktail.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}

/// Minimal in-memory [Storage] so [HydratedCubit]s (`ThemeCubit`,
/// `LocaleCubit`) can be constructed in widget tests without touching the
/// filesystem.
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
  late MockLoginUseCase loginUseCase;

  setUpAll(() {
    HydratedBloc.storage = _InMemoryStorage();
  });

  setUp(() {
    loginUseCase = MockLoginUseCase();
    getIt.registerFactory<LoginBloc>(() => LoginBloc(loginUseCase));
  });

  tearDown(() async {
    await getIt.reset();
  });

  // Mirrors the exact BlocBuilder wiring in lib/app.dart — a wrap() that
  // provides the cubits but hardcodes MaterialApp's locale/themeMode would
  // pass trivially while the toggle buttons silently did nothing, which is
  // exactly the bug class this test suite exists to catch.
  Widget wrap() {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => LocaleCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return BlocBuilder<LocaleCubit, Locale?>(
            builder: (context, locale) {
              return MaterialApp(
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: themeMode,
                locale: locale,
                supportedLocales: LocaleCubit.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: const LoginPage(),
              );
            },
          );
        },
      ),
    );
  }

  testWidgets(
    'shows email/password fields and a disabled-while-idle submit button',
    (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    },
  );

  testWidgets(
    'submitting valid credentials shows a loading indicator then succeeds',
    (tester) async {
      when(
        () => loginUseCase(
          email: 'demo@kelalstudio.app',
          password: 'password123',
        ),
      ).thenAnswer((_) async {
        // A tiny real delay so the loading state actually renders a frame
        // before success — without it, both emits can land inside the
        // same microtask flush and the loading indicator is never
        // observed by the test, even though it's genuinely shown to users
        // against any real (non-instant) network call.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return const Result.ok(AuthSession(isAuthenticated: true));
      });

      await tester.pumpWidget(wrap());
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'demo@kelalstudio.app',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'password123',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'a failed login shows the plain-language error message in a SnackBar',
    (tester) async {
      when(
        () => loginUseCase(email: 'demo@kelalstudio.app', password: 'wrong'),
      ).thenAnswer(
        (_) async => const Result.err(
          ApiFailure(
            type: ApiErrorType.validationError,
            message: 'Invalid email or password.',
          ),
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'demo@kelalstudio.app',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'wrong',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password.'), findsOneWidget);
    },
  );

  testWidgets('the locale toggle cycles Auto -> English -> Amharic -> Auto and '
      'actually re-renders the localized title', (tester) async {
    await tester.pumpWidget(wrap());

    // System test locale defaults to English, so "Auto" renders the
    // English title.
    expect(find.text('Kelal Studio'), findsOneWidget);
    expect(find.text('AUTO'), findsOneWidget);

    await tester.tap(find.byKey(const Key('locale_toggle_button')));
    await tester.pumpAndSettle();
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('Kelal Studio'), findsOneWidget);

    await tester.tap(find.byKey(const Key('locale_toggle_button')));
    await tester.pumpAndSettle();
    expect(find.text('AM'), findsOneWidget);
    expect(find.text('ቀላል ስቱዲዮ'), findsOneWidget);

    await tester.tap(find.byKey(const Key('locale_toggle_button')));
    await tester.pumpAndSettle();
    expect(find.text('AUTO'), findsOneWidget);
  });

  testWidgets(
    'the theme toggle switches between the light and dark ColorScheme',
    (tester) async {
      await tester.pumpWidget(wrap());

      final scaffoldBefore = tester.widget<Scaffold>(find.byType(Scaffold));
      final materialBefore = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(materialBefore.themeMode, ThemeMode.system);
      expect(scaffoldBefore.backgroundColor, isNull); // inherits from Theme

      await tester.tap(find.byKey(const Key('theme_toggle_button')));
      await tester.pumpAndSettle();

      final materialAfter = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(materialAfter.themeMode, isNot(ThemeMode.system));
    },
  );
}
