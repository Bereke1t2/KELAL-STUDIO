import 'package:flutter/material.dart';
import 'package:kelal_studio/core/widgets/bottom_nav_bar.dart';

import 'golden_helpers.dart';

/// Golden coverage for [BottomNavBar] — Figma `Components / Bottom
/// Navigation`, canvas `37:2`, tab row `37:62`. Built from the
/// Components-page definition, not the under-specified Pages-tab
/// placeholder — see the doc comment on `bottom_nav_bar.dart` and the
/// "Bottom navigation" section of `flutter-design-system/SKILL.md`.
void main() {
  const englishItems = [
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
  const amharicItems = [
    BottomNavBarItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'መነሻ',
    ),
    BottomNavBarItem(icon: Icons.add, label: 'ፍጠር'),
    BottomNavBarItem(
      icon: Icons.collections_outlined,
      selectedIcon: Icons.collections,
      label: 'ቤተ-መጻሕፍት',
    ),
    BottomNavBarItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'ቅንብሮች',
    ),
  ];

  goldenThemeTest(
    'Bottom nav bar renders the active pill and raised create action',
    fileName: 'bottom_nav_bar',
    variants: {
      'home active - english': (context) => BottomNavBar(
        items: englishItems,
        selectedIndex: 0,
        prominentIndex: 1,
        onTap: (_) {},
      ),
      'library active - amharic': (context) => BottomNavBar(
        items: amharicItems,
        selectedIndex: 2,
        prominentIndex: 1,
        onTap: (_) {},
      ),
    },
  );
}
