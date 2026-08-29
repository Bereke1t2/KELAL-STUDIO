import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/l10n/locale_cubit.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/features/auth/domain/repositories/auth_repository.dart';
import 'package:kelal_studio/features/auth/presentation/widgets/email_verification_gate.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository authRepository;

  setUp(() {
    authRepository = MockAuthRepository();
    getIt.registerLazySingleton<AuthRepository>(() => authRepository);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget wrap() {
    return MaterialApp(
      theme: AppTheme.light(),
      supportedLocales: LocaleCubit.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const EmailVerificationGate(
        child: Center(child: Text('compose placeholder')),
      ),
    );
  }

  testWidgets(
    'shows no banner and renders the child when the email is verified',
    (tester) async {
      when(
        () => authRepository.watchEmailVerified(),
      ).thenAnswer((_) => Stream.value(true));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('compose placeholder'), findsOneWidget);
      expect(
        find.byKey(const Key('email_verification_gate_banner')),
        findsNothing,
      );
    },
  );

  testWidgets('shows the blocking banner above the child when the email is not '
      'verified (PRD §6.1: email verification gates content generation)', (
    tester,
  ) async {
    when(
      () => authRepository.watchEmailVerified(),
    ).thenAnswer((_) => Stream.value(false));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('email_verification_gate_banner')),
      findsOneWidget,
    );
    // The gated content is still present underneath — this is a banner,
    // not a screen swap (Compose has nothing to literally disable yet in
    // this branch; see the flagged gap in the widget's doc comment).
    expect(find.text('compose placeholder'), findsOneWidget);
  });

  testWidgets(
    'does not show the banner while the stream is still unresolved (no '
    'emission yet) — mirrors AppRouter.authRedirect treating a null state '
    'as "not yet known" rather than assuming unverified',
    (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);
      when(
        () => authRepository.watchEmailVerified(),
      ).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(
        find.byKey(const Key('email_verification_gate_banner')),
        findsNothing,
      );
    },
  );
}
