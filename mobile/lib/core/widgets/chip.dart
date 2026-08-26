import 'package:flutter/material.dart';

import 'package:kelal_studio/core/theme/app_theme.dart';

/// Selectable tag/chip — Figma `Components / Chip` (documented as "Badge"
/// in the file; node `18:2` "Type=Neutral, State=Default" and `18:4`
/// "Type=Neutral, State=Selected"). Pill background, no border.
///
/// The selected state's fill (`#171717` light) matches [AppColors.bgInverse]
/// exactly, and its text/check color (`color-text-inverse`, `#fafafa`
/// fallback) has no dedicated field in [AppColors] — it's reused as
/// [AppColors.bgSurface] here, mirroring the same reuse already established
/// in `app_theme.dart`'s `elevatedButtonThemeData.foregroundColor` for
/// "white text on a dark/brand fill". The Figma pull also shows the
/// checkmark glyph at 11px; that's folded into [AppTypography.caption]
/// (12px) instead of a new one-off size, per the "never hardcode a raw
/// pixel number" rule.
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final String label;
  final bool selected;

  /// When null, the chip renders as a static (non-interactive) tag.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textColor = selected ? colors.bgSurface : colors.textSecondary;
    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: selected ? colors.bgInverse : colors.bgDisabled,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            Text('✓', style: AppTypography.caption.copyWith(color: textColor)),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(label, style: AppTypography.caption.copyWith(color: textColor)),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: content,
    );
  }
}
