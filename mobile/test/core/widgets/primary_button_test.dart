import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/primary_button.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('shows label and invokes onPressed when idle', (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(
      _wrap(PrimaryButton(label: 'Sign in', onPressed: () => tapCount++)),
    );

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets(
    'isLoading swaps the label for a spinner and disables the button',
    (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        _wrap(
          PrimaryButton(
            label: 'Sign in',
            isLoading: true,
            onPressed: () => tapCount++,
          ),
        ),
      );

      expect(find.text('Sign in'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);

      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pump();

      expect(tapCount, 0);
    },
  );

  testWidgets('a null onPressed disables the button regardless of isLoading', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const PrimaryButton(label: 'Sign in', onPressed: null)),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('an icon renders before the label when provided', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PrimaryButton(
          label: 'Generate',
          icon: Icons.auto_awesome,
          onPressed: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.text('Generate'), findsOneWidget);
  });

  testWidgets('omitting icon renders exactly as before this parameter '
      'existed — text-only, no icon in the tree', (tester) async {
    await tester.pumpWidget(
      _wrap(PrimaryButton(label: 'Sign in', onPressed: () {})),
    );

    expect(find.byType(Icon), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('isLoading hides the icon too, same as it hides the label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        PrimaryButton(
          label: 'Generate',
          icon: Icons.auto_awesome,
          isLoading: true,
          onPressed: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.auto_awesome), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
