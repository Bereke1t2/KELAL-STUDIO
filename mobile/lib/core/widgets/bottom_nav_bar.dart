/// Presentational-only bottom navigation bar — Figma `Components / Bottom
/// Navigation`, canvas `37:2`. **This is the caveat node flagged in the
/// task**: the file's Pages tab shows the bottom nav only as a generic
/// unstyled placeholder (e.g. "Screens / Home & Dashboard", node `58:18`,
/// just a frame named "Frame" containing one text node literally named
/// "Nav" with no real icon/pill/FAB detail — same in every other screen
/// that includes a nav row, e.g. `58:39`, `58:51`). The Components page
/// (`37:2`) has the real, complete definition — a pill-shaped bar
/// (`AppRadius.full`) with 4 tabs, where the active tab gets an
/// `AppColors.bgBrandSubtle` pill behind brand-colored icon/label, and a
/// raised circular "Create" action sits in the second slot. This widget
/// follows the Components-page version per the task's explicit
/// instruction, not the under-specified Pages-tab one.
///
/// This is presentation only — no `go_router`/`ShellRoute` wiring here;
/// that's for the branch that adds routing.
library;

import 'package:flutter/material.dart';

import 'package:kelal_studio/core/theme/app_theme.dart';

class BottomNavBarItem {
  const BottomNavBarItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final IconData icon;

  /// Optional distinct icon for the selected state; falls back to [icon].
  final IconData? selectedIcon;
  final String label;
}

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    this.prominentIndex,
    super.key,
  }) : assert(items.length >= 2, 'A nav bar needs at least 2 destinations');

  final List<BottomNavBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  /// Index of the item rendered as a raised circular action (Figma's
  /// "Create" tab, index 1 of 4) instead of the standard icon+label pill.
  /// Null renders every item uniformly.
  final int? prominentIndex;

  /// `rgba(23, 15, 5, 0.14)`, Figma's literal drop-shadow spec on the nav
  /// bar — not a bound Figma variable (the pulled reference code uses a
  /// raw Tailwind arbitrary value, not a `var(--color-*)` token), so
  /// there's no semantic `AppColors` field to route it through; kept
  /// local rather than added to the shared token file for a single-use
  /// effect value.
  static const _shadowColor = Color(0x24170F05);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 64,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.bgSurfaceRaised,
        border: Border.all(color: colors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: const [
          BoxShadow(color: _shadowColor, blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: i == prominentIndex
                  ? _ProminentTab(item: items[i], onTap: () => onTap(i))
                  : _Tab(
                      item: items[i],
                      selected: i == selectedIndex,
                      onTap: () => onTap(i),
                    ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final BottomNavBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.primaryDefault : colors.textTertiary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        // Vertical padding is AppSpacing.xxs here, not the sm (8px) Figma's
        // pull shows (py-6, close to sm) — this app's AppTypography fixes
        // Ethiopic line-height at 1.55x everywhere (never overridden per
        // style; see app_typography.dart), which is taller than the
        // Figma proof font's metrics. At sm padding, icon + gap + label
        // overflow the bar's fixed 64px height; xxs keeps every state
        // fitting without shrinking the bar or touching the line-height
        // rule.
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.bgBrandSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? (item.selectedIcon ?? item.icon) : item.icon,
              size: 22,
              color: color,
            ),
            // No gap here (Figma shows a 2px/xxs gap) — with this app's
            // fixed 1.55x Ethiopic line-height, even a 2px gap overflows
            // the bar's fixed 64px height by ~1px; see the padding
            // comment above for the full explanation.
            // maxLines/softWrap/overflow pin this to a single line
            // regardless of label length/language — a longer word (English
            // or Amharic) wrapping to 2 lines is exactly what overflowed
            // the bar's fixed 64px height during testing; ellipsis is
            // safer than letting an arbitrary caller-supplied label break
            // the bar's layout.
            Text(
              item.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProminentTab extends StatelessWidget {
  const _ProminentTab({required this.item, required this.onTap});

  final BottomNavBarItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -10),
        child: Semantics(
          button: true,
          label: item.label,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primaryDefault,
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: colors.bgSurface, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
