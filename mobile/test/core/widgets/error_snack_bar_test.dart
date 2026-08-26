import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/error_snack_bar.dart';

void main() {
  testWidgets('showErrorSnackBar surfaces the given message in a SnackBar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showErrorSnackBar(context, 'Invalid email or password.'),
              child: const Text('Trigger'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pump();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
