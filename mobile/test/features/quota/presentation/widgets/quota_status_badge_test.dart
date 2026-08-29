import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/quota_badge.dart';
import 'package:kelal_studio/features/quota/domain/entities/quota.dart';
import 'package:kelal_studio/features/quota/domain/usecases/get_quota_usecase.dart';
import 'package:kelal_studio/features/quota/presentation/bloc/quota_bloc.dart';
import 'package:kelal_studio/features/quota/presentation/widgets/quota_status_badge.dart';
import 'package:mocktail/mocktail.dart';

class MockGetQuotaUseCase extends Mock implements GetQuotaUseCase {}

void main() {
  late MockGetQuotaUseCase getQuotaUseCase;

  setUp(() {
    getQuotaUseCase = MockGetQuotaUseCase();
    getIt.registerFactory<QuotaBloc>(() => QuotaBloc(getQuotaUseCase));
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
      home: const Scaffold(body: QuotaStatusBadge()),
    );
  }

  testWidgets('shows the loading badge while the fetch is in flight', (
    tester,
  ) async {
    when(getQuotaUseCase.call).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return Result.ok(
        Quota(
          textCallsUsed: 3,
          textCallsLimit: 10,
          imageCallsUsed: 1,
          imageCallsLimit: 5,
          resetsAt: DateTime.utc(2026, 1, 1, 18),
        ),
      );
    });

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byKey(const Key('quota_badge_loading')), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'once loaded, formats remaining-count labels and the local reset time '
    'without warning styling when usage is well under the limit',
    (tester) async {
      final resetsAt = DateTime.utc(2026, 1, 1, 18);
      when(getQuotaUseCase.call).thenAnswer(
        (_) async => Result.ok(
          Quota(
            textCallsUsed: 3,
            textCallsLimit: 10,
            imageCallsUsed: 1,
            imageCallsLimit: 5,
            resetsAt: resetsAt,
          ),
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final expectedTime = DateFormat.jm().format(resetsAt.toLocal());
      expect(find.text('7 of 10 text calls remaining today'), findsOneWidget);
      expect(find.text('4 of 5 image calls remaining today'), findsOneWidget);
      expect(find.text('Resets at $expectedTime'), findsOneWidget);

      final badge = tester.widget<QuotaBadge>(find.byType(QuotaBadge));
      expect(badge.isWarning, isFalse);
    },
  );

  testWidgets('flags isWarning once a resource is exhausted', (tester) async {
    when(getQuotaUseCase.call).thenAnswer(
      (_) async => Result.ok(
        Quota(
          textCallsUsed: 10,
          textCallsLimit: 10,
          imageCallsUsed: 2,
          imageCallsLimit: 5,
          resetsAt: DateTime.utc(2026, 1, 1, 18),
        ),
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final badge = tester.widget<QuotaBadge>(find.byType(QuotaBadge));
    expect(badge.isWarning, isTrue);
    expect(find.text('0 of 10 text calls remaining today'), findsOneWidget);
  });

  testWidgets('a failed fetch shows the error badge with the plain-language '
      'message', (tester) async {
    when(getQuotaUseCase.call).thenAnswer(
      (_) async => const Result.err(
        ApiFailure(
          type: ApiErrorType.network,
          message: 'No connection. Check your network and try again.',
        ),
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quota_badge_error')), findsOneWidget);
    expect(
      find.text('No connection. Check your network and try again.'),
      findsOneWidget,
    );
  });
}
