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
    super.key,
  }) : assert(
         labels.length > 1,
         'A segmented control needs at least 2 segments',
       );

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: selected ? colors.textPrimary : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
