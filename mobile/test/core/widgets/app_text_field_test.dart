import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/app_text_field.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('entering text invokes onChanged with the new value', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(
      _wrap(
        AppTextField(
          label: 'Business Email',
          onChanged: (value) => changed = value,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'demo@kelalstudio.app');

    expect(changed, 'demo@kelalstudio.app');
  });

  testWidgets('errorText renders as the field helper text', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AppTextField(
          label: 'Business Email',
          errorText: 'Enter a valid email address.',
        ),
      ),
    );

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('enabled: false disables the field', (tester) async {
    await tester.pumpWidget(
      _wrap(const AppTextField(label: 'Business Email', enabled: false)),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
  });
}
