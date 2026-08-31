import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/segmented_control.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('tapping an unselected segment reports its index', (
    tester,
  ) async {
    int? tappedIndex;
    await tester.pumpWidget(
      _wrap(
        AppSegmentedControl(
          labels: const ['Post', 'Story', 'Reel'],
          selectedIndex: 0,
          onChanged: (index) => tappedIndex = index,
        ),
      ),
    );

    await tester.tap(find.text('Reel'));
    await tester.pumpAndSettle();

    expect(tappedIndex, 2);
  });

  testWidgets('tapping the already-selected segment still reports its index', (
    tester,
  ) async {
    int? tappedIndex;
    await tester.pumpWidget(
      _wrap(
        AppSegmentedControl(
          labels: const ['Post', 'Story'],
          selectedIndex: 1,
          onChanged: (index) => tappedIndex = index,
        ),
      ),
    );

    await tester.tap(find.text('Story'));
    await tester.pumpAndSettle();

    expect(tappedIndex, 1);
  });

  testWidgets('an icon renders before each label when icons is provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AppSegmentedControl(
          labels: const ['Post', 'Story'],
          icons: const [Icons.image_outlined, Icons.auto_stories_outlined],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);
  });

  testWidgets('omitting icons renders exactly as before this parameter '
      'existed — text-only, no icon in the tree', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AppSegmentedControl(
          labels: const ['Post', 'Story'],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.byType(Icon), findsNothing);
  });
}
