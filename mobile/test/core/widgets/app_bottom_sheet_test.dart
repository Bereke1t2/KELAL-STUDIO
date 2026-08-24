import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/app_bottom_sheet.dart';

Widget _wrap(WidgetBuilder builder) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Builder(builder: builder)),
);

void main() {
  testWidgets(
    'showAppBottomSheet presents the sheet and its primary action fires',
    (tester) async {
      var deleted = false;
      await tester.pumpWidget(
        _wrap(
          (context) => ElevatedButton(
            onPressed: () => showAppBottomSheet<void>(
              context,
              sheet: AppBottomSheet(
                heading: 'Delete this draft?',
                body: 'This cannot be undone.',
                primaryLabel: 'Delete Draft',
                onPrimaryPressed: () => deleted = true,
                isDestructive: true,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this draft?'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('app_bottom_sheet_primary_button')),
      );
      await tester.pump();

      expect(deleted, isTrue);
    },
  );

  testWidgets('showAppDialog presents the dialog and its action fires', (
    tester,
  ) async {
    var restarted = false;
    await tester.pumpWidget(
      _wrap(
        (context) => ElevatedButton(
          onPressed: () => showAppDialog<void>(
            context,
            dialog: AppDialog(
              icon: Icons.error_outline,
              heading: "Kelal couldn't start",
              body: 'Try restarting the app.',
              actionLabel: 'Restart Kelal',
              onActionPressed: () => restarted = true,
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text("Kelal couldn't start"), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_dialog_action_button')));
    await tester.pump();

    expect(restarted, isTrue);
  });
}
