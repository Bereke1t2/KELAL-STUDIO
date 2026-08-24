import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/quota_exceeded_dialog.dart';

Widget _wrap(VoidCallback onPressed) {
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('am')],
    home: Scaffold(
      body: Builder(
        builder: (context) =>
            ElevatedButton(onPressed: onPressed, child: const Text('open')),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the reset time formatted from ApiFailure.resetsAt', (
    tester,
  ) async {
    final resetsAt = DateTime.utc(2026, 1, 1, 18, 30);
    late BuildContext capturedContext;

    // Drive the dialog directly from a captured `BuildContext` (no tap
    // needed) so this test controls exactly which `ApiFailure` is
    // passed in.
    await tester.pumpWidget(_wrap(() {}));
    capturedContext = tester.element(find.byType(ElevatedButton));

    unawaited(
      showQuotaExceededDialog(
        capturedContext,
        ApiFailure(
          type: ApiErrorType.quotaExceeded,
          message: "You've used today's generation quota. It resets soon.",
          resetsAt: resetsAt,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Format the same way the widget under test does, rather than
    // hardcoding an expected string — keeps this test correct
    // regardless of the machine's local timezone.
    final expectedTime = DateFormat.jm().format(resetsAt.toLocal());

    expect(find.text('Quota reached'), findsOneWidget);
    expect(
      find.text(
        "You've used today's generation quota. It resets at "
        '$expectedTime.',
      ),
      findsOneWidget,
    );
    expect(find.text('Got it'), findsOneWidget);
  });

  testWidgets(
    'falls back to a resets-soon message when ApiFailure.resetsAt is null',
    (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(_wrap(() {}));
      capturedContext = tester.element(find.byType(ElevatedButton));

      unawaited(
        showQuotaExceededDialog(
          capturedContext,
          const ApiFailure(
            type: ApiErrorType.quotaExceeded,
            message: "You've used today's generation quota. It resets soon.",
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("You've used today's generation quota. It will reset soon."),
        findsOneWidget,
      );
    },
  );

  testWidgets('tapping the action dismisses the dialog', (tester) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(_wrap(() {}));
    capturedContext = tester.element(find.byType(ElevatedButton));

    unawaited(
      showQuotaExceededDialog(
        capturedContext,
        ApiFailure(
          type: ApiErrorType.quotaExceeded,
          message: "You've used today's generation quota. It resets soon.",
          resetsAt: DateTime.utc(2026),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quota reached'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Quota reached'), findsNothing);
  });
}
