import 'package:flutter/material.dart';

import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/primary_button.dart';

/// Illustration + copy + optional CTA pattern for empty/first-run states —
/// Figma `Components / Empty State`, node `45:2`, variants "Home — First
/// Run" (`45:6`) and "Drafts Library — Empty" (`45:13`); both share this
/// exact structure (circular brand-subtle mark with a centered glyph,
/// heading, body, optional full-width-ish CTA), so one widget covers both.
///
/// The Figma CTA is a fixed 220px wide button inside a centered card; that
/// exact pixel width has no matching [AppSpacing] token and isn't load
/// bearing to the design intent, so it's left as the button's natural
/// intrinsic size instead of hardcoding a raw `220` — everything else
/// (56px mark, 22px glyph, and all internal gaps, which are a uniform
/// [AppSpacing.lg] top to bottom) maps to real tokens.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.heading,
    required this.body,
    this.ctaLabel,
    this.onCtaPressed,
    super.key,
  });

  /// Glyph shown inside the brand-subtle circular mark.
  final IconData icon;
  final String heading;
  final String body;

  /// When both this and [onCtaPressed] are set, a [PrimaryButton] is shown.
  final String? ctaLabel;
  final VoidCallback? onCtaPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxxl,
        vertical: AppSpacing.xxxxxl,
      ),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.bgBrandSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: colors.primaryDefault),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            heading,
            textAlign: TextAlign.center,
            style: AppTypography.title.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          if (ctaLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(label: ctaLabel!, onPressed: onCtaPressed),
          ],
        ],
      ),
    );
  }
}
