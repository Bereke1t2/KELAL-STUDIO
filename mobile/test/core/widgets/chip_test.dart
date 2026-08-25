import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/chip.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('tapping an interactive chip invokes onTap', (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(
      _wrap(AppChip(label: 'Coffee', onTap: () => tapCount++)),
    );

    await tester.tap(find.text('Coffee'));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('a static chip (no onTap) does not respond to InkWell taps', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const AppChip(label: 'Coffee')));

    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('selected state renders a checkmark alongside the label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AppChip(label: 'Coffee', selected: true)),
    );

    expect(find.text('✓'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
  });
}
