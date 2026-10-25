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
    await tester.pumpAndSettle();

    expect(restarted, isTrue);
    // AppDialog dismisses itself after the callback runs — the caller's
    // onActionPressed is never responsible for popping (see the next
    // test for why a caller that pops anyway used to crash the app).
    expect(find.text("Kelal couldn't start"), findsNothing);
  });

  testWidgets(
    "showAppDialog's action button pops only the dialog itself, never a "
    "navigator the caller's pre-dialog context happens to belong to — "
    'regression test for the real crash this app shipped with: '
    '`showAppDialog` pushes onto the *root* navigator, but a caller shown '
    'from inside a nested navigator (e.g. a bottom-nav tab branch) that '
    'called `Navigator.of(thatContext).pop()` itself was popping its own '
    "nested navigator's sole route instead of the dialog, crashing with "
    '"popped the last page off of the stack" (go_router) — see '
    '`quota_exceeded_dialog.dart`.',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          (outerContext) => Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (nestedContext) => ElevatedButton(
                onPressed: () => showAppDialog<void>(
                  nestedContext,
                  dialog: AppDialog(
                    icon: Icons.error_outline,
                    heading: 'Quota reached',
                    body: 'Try again tomorrow.',
                    actionLabel: 'Got it',
                    // The exact shape of the original bug: a caller that
                    // (wrongly) tries to dismiss the dialog itself using
                    // its own pre-dialog context.
                    onActionPressed: () {},
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Quota reached'), findsOneWidget);

      await tester.tap(find.byKey(const Key('app_dialog_action_button')));
      await tester.pumpAndSettle();

      // The dialog is gone...
      expect(find.text('Quota reached'), findsNothing);
      // ...and the nested Navigator's own page survived — it was never
      // popped along with the dialog.
      expect(find.text('Open'), findsOneWidget);
    },
  );
}
