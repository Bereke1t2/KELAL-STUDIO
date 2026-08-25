import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/empty_state.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('renders heading and body without a CTA when omitted', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const EmptyState(
          icon: Icons.folder_open_outlined,
          heading: 'No drafts yet',
          body: 'Drafts you save while composing will show up here.',
        ),
      ),
    );

    expect(find.text('No drafts yet'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('tapping the CTA invokes onCtaPressed', (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(
      _wrap(
        EmptyState(
          icon: Icons.auto_awesome_outlined,
          heading: 'Your first post starts here',
          body: 'Tell Kelal what you’re promoting.',
          ctaLabel: 'Create Your First Post',
          onCtaPressed: () => tapCount++,
        ),
      ),
    );

    await tester.tap(find.text('Create Your First Post'));
    await tester.pump();

    expect(tapCount, 1);
  });
}
