import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/quota_badge.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('loading state shows a compact spinner and no label text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const QuotaBadge(status: QuotaBadgeStatus.loading)),
    );
    // The spinner is indeterminate, so don't pumpAndSettle (it never
    // settles) — a single pump is enough to assert presence.
    await tester.pump();

    expect(find.byKey(const Key('quota_badge_loading')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'loaded state shows both remaining-calls labels and the reset label',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const QuotaBadge(
            status: QuotaBadgeStatus.loaded,
            textRemainingLabel: '7 of 10 text calls remaining today',
            imageRemainingLabel: '4 of 5 image calls remaining today',
            resetLabel: 'Resets at 6:00 PM',
          ),
        ),
      );

      expect(find.byKey(const Key('quota_badge_loaded')), findsOneWidget);
      expect(find.text('7 of 10 text calls remaining today'), findsOneWidget);
      expect(find.text('4 of 5 image calls remaining today'), findsOneWidget);
      expect(find.text('Resets at 6:00 PM'), findsOneWidget);
    },
  );

  testWidgets('isWarning renders the loaded state in the warning color triad', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const QuotaBadge(
          status: QuotaBadgeStatus.loaded,
          textRemainingLabel: '0 of 10 text calls remaining today',
          imageRemainingLabel: '0 of 5 image calls remaining today',
          resetLabel: 'Resets at 6:00 PM',
          isWarning: true,
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.byKey(const Key('quota_badge_loaded')),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.light.warningBg);
    expect(decoration.border, Border.all(color: AppColors.light.warningBorder));

    final textStyle = tester
        .widget<Text>(find.text('0 of 10 text calls remaining today'))
        .style;
    expect(textStyle?.color, AppColors.light.warningText);
  });

  testWidgets('error state shows the given plain-language message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const QuotaBadge(
          status: QuotaBadgeStatus.error,
          errorMessage: 'No connection. Check your network and try again.',
        ),
      ),
    );

    expect(find.byKey(const Key('quota_badge_error')), findsOneWidget);
    expect(
      find.text('No connection. Check your network and try again.'),
      findsOneWidget,
    );
  });
}
