import 'package:flutter/material.dart';

import 'package:kelal_studio/core/theme/app_theme.dart';

/// Tab-style segmented toggle (e.g. platform picker, ratio picker).
///
/// **No dedicated Figma node for this component was found.** Per
/// `flutter-design-system/SKILL.md`, `get_design_context` was called
/// against every plausible node in `0dIrGk2LyVEseP6Tz1KxMa` (a systematic
/// sweep of the file's node-id space, not a guess from memory) and no
/// "Segmented Control" / "Tab" component turned up — only a *screen* that
/// visually resembles one (Onboarding & Auth → "Business Input", node
/// `61:24`, a two-option picker) without enough detail to reverse the
/// component from. This widget is therefore built from the same tokens
/// `AppChip` uses (pill track, `AppRadius.full`, `bgDisabled`/`bgSurface`/
/// `textSecondary`/`textPrimary`) for visual consistency with the rest of
/// the system, **not** pulled 1:1 — flag this for a real Figma pull if/when
/// a "Segmented Control" component is added to the file.
class AppSegmentedControl extends StatelessWidget {
  const AppSegmentedControl({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.icons,
    super.key,
  }) : assert(
         labels.length > 1,
         'A segmented control needs at least 2 segments',
       ),
       assert(
         icons == null || icons.length == labels.length,
         'icons, when provided, must have one entry per label',
       );

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// One icon per [labels] entry, shown before its text. `null` (the
  /// default) renders text-only, exactly as before this was added — every
  /// existing call site (aspect-ratio pickers in canvas editor/export)
  /// keeps its current look unless it opts in.
  final List<IconData>? icons;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: colors.bgDisabled,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: _Segment(
                label: labels[i],
                icon: icons?[i],
                selected: i == selectedIndex,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.textPrimary : colors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? colors.bgSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(label, style: AppTypography.bodySmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
