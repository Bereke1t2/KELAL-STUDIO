import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/widgets/bottom_nav_bar.dart';

/// Hosts the 4 bottom-nav branches (Compose/Drafts/Brand/Settings) behind
/// go_router's `StatefulShellRoute.indexedStack` — each branch keeps its
/// own navigation stack/scroll position across tab switches, which a plain
/// hand-rolled `IndexedStack` wouldn't give for free.
///
/// No [BottomNavBar.prominentIndex] is set here: that widget's Figma spec
/// (see its doc comment) raises a distinct "Create" action out of an
/// otherwise plain Home/Library/Settings row. This shell's 4 tabs are all
/// full destinations of equal weight — Compose already *is* the primary
/// "create" surface as its own tab, so singling it out again as a raised
/// action on top of that would just be visual noise, not a second
/// distinct affordance. Revisit once the real Idea Composer UX exists and
/// there's an actual case for a prominent quick-create shortcut.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavBar(
        items: [
          BottomNavBarItem(
            icon: Icons.edit_outlined,
            selectedIcon: Icons.edit,
            label: l10n.navComposeLabel,
          ),
          BottomNavBarItem(
            icon: Icons.description_outlined,
            selectedIcon: Icons.description,
            label: l10n.navDraftsLabel,
          ),
          BottomNavBarItem(
            icon: Icons.palette_outlined,
            selectedIcon: Icons.palette,
            label: l10n.navBrandLabel,
          ),
          BottomNavBarItem(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: l10n.navSettingsLabel,
          ),
        ],
        selectedIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          // Re-root to the branch's initial location when re-tapping the
          // already-active tab — the standard go_router
          // StatefulShellRoute pattern; a no-op today since every branch
          // is a single placeholder page with no nested stack yet.
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
