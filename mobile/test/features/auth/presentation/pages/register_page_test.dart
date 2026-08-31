import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/l10n/locale_cubit.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/features/auth/domain/entities/registration_outcome.dart';
import 'package:kelal_studio/features/auth/domain/usecases/register_usecase.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/register_bloc.dart';
import 'package:kelal_studio/features/auth/presentation/pages/register_page.dart';
import 'package:mocktail/mocktail.dart';

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

void main() {
  late MockRegisterUseCase registerUseCase;

  setUp(() {
    registerUseCase = MockRegisterUseCase();
    getIt.registerFactory<RegisterBloc>(() => RegisterBloc(registerUseCase));
  });

  tearDown(() async {
    await getIt.reset();
  });

  // Registration navigates itself on success now (RegisterPage no longer
  // relies on AppRouter's auth-state redirect — see RegisterPage's
  // listener doc comment), so this needs a real GoRouter ancestor, unlike
  // before. A minimal two-route router (not the full AppRouter) is enough
  // to prove *that* navigation happened, with the right query param.
  Widget wrap() {
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: '/verify-email',
          builder: (context, state) => Scaffold(
            body: Text('verify-email:${state.uri.queryParameters['email']}'),
          ),
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.light(),
      supportedLocales: LocaleCubit.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }

  testWidgets('shows email/password fields and a submit button', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    expect(find.byKey(const Key('register_email_field')), findsOneWidget);
    expect(find.byKey(const Key('register_password_field')), findsOneWidget);
    expect(find.byKey(const Key('register_submit_button')), findsOneWidget);
  });

  testWidgets(
    'submitting valid details shows a loading indicator, then navigates '
    'to Check Your Email with the registered address',
    (tester) async {
      when(
        () => registerUseCase(
          email: 'new@kelalstudio.app',
          password: 'password123',
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return const Result.ok(
          RegistrationOutcome(userId: 'user-1', verificationSent: true),
        );
      });

      await tester.pumpWidget(wrap());
      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'new@kelalstudio.app',
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        'password123',
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('verify-email:new@kelalstudio.app'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed registration (e.g. email already exists) shows the backend '
    'message directly — unlike login, register is not anti-enumeration '
    'scoped, so no client-side message override is applied',
    (tester) async {
      when(
        () => registerUseCase(
          email: 'dup@kelalstudio.app',
          password: 'password123',
        ),
      ).thenAnswer(
        (_) async => const Result.err(
          ApiFailure(
            type: ApiErrorType.validationError,
            message: 'An account with this email already exists.',
          ),
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'dup@kelalstudio.app',
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        'password123',
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('An account with this email already exists.'),
        findsOneWidget,
      );
    },
  );
}
