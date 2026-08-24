import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/error_banner.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('renders title and message', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ErrorBanner(
          title: 'Error',
          message: 'Generation failed. Try again.',
        ),
      ),
    );

    expect(find.text('Error'), findsOneWidget);
    expect(find.text('Generation failed. Try again.'), findsOneWidget);
  });

  testWidgets('has no dismiss affordance when onDismiss is omitted', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const ErrorBanner(message: 'Draft could not be saved.')),
    );

    expect(find.byKey(const Key('error_banner_dismiss_button')), findsNothing);
  });

  testWidgets('tapping dismiss invokes onDismiss exactly once', (tester) async {
    var dismissCount = 0;
    await tester.pumpWidget(
      _wrap(
        ErrorBanner(
          message: 'Generation failed. Try again.',
          onDismiss: () => dismissCount++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('error_banner_dismiss_button')));
    await tester.pump();

    expect(dismissCount, 1);
  });
}
