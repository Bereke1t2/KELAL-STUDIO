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

  testWidgets('renders a leading icon when icon is provided', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ErrorBanner(
          icon: Icons.mark_email_unread_outlined,
          title: 'Verify your email',
          message: 'Check your inbox for a verification link.',
        ),
      ),
    );

    expect(find.byIcon(Icons.mark_email_unread_outlined), findsOneWidget);
  });

  testWidgets('omitting icon renders exactly as before this parameter '
      'existed — no icon in the tree', (tester) async {
    await tester.pumpWidget(
      _wrap(const ErrorBanner(message: 'Draft could not be saved.')),
    );

    expect(find.byType(Icon), findsNothing);
  });
}
