import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/bottom_nav_bar.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

const _items = [
  BottomNavBarItem(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Home',
  ),
  BottomNavBarItem(icon: Icons.add, label: 'Create'),
  BottomNavBarItem(
    icon: Icons.collections_outlined,
    selectedIcon: Icons.collections,
    label: 'Library',
  ),
  BottomNavBarItem(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: 'Settings',
  ),
];

void main() {
  testWidgets('tapping a standard tab reports its index', (tester) async {
    int? tappedIndex;
    await tester.pumpWidget(
      _wrap(
        BottomNavBar(
          items: _items,
          selectedIndex: 0,
          prominentIndex: 1,
          onTap: (index) => tappedIndex = index,
        ),
      ),
    );

    await tester.tap(find.text('Library'));
    await tester.pump();

    expect(tappedIndex, 2);
  });

  testWidgets('tapping the prominent (Create) tab reports its index', (
    tester,
  ) async {
    int? tappedIndex;
    await tester.pumpWidget(
      _wrap(
        BottomNavBar(
          items: _items,
          selectedIndex: 0,
          prominentIndex: 1,
          onTap: (index) => tappedIndex = index,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(tappedIndex, 1);
  });

  testWidgets('the selected tab shows its filled selectedIcon', (tester) async {
    await tester.pumpWidget(
      _wrap(
        BottomNavBar(
          items: _items,
          selectedIndex: 0,
          prominentIndex: 1,
          onTap: (_) {},
        ),
      ),
    );

    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
  });
}
