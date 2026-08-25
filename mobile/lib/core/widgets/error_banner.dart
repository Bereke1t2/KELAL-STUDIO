import 'package:flutter/material.dart';

import 'package:kelal_studio/core/theme/app_theme.dart';

/// Inline error banner — Figma Color Foundations, `Color — Feedback`
/// section (node `11:11`, the "Error" swatch of the Success/Warning/
/// Error/Info group at `11:4`). That section is explicitly documented in
/// the file as "Powers Toast/Banner and Badge components directly" (node
/// `11:3`), so this widget's bg/border/text triad is a direct,
/// intentional pull rather than a stand-in for a missing "Toast"
/// component.
///
/// The Figma swatch renders its title in bold (`font-bold`), but
/// `AppTypography`/`flutter-ethiopic-typography` are explicit that
/// hierarchy in this app comes from size/spacing/color only, never
/// [FontWeight.bold] (see the doc comment on `AppTypography` and the
/// review checklist's Ethiopic section) — so the title below uses
/// [AppTypography.label] plus the error text color for emphasis instead
/// of bold, deliberately deviating from the raw Figma pull to match this
/// project's typography rule. The Figma gap between title and body (10px)
/// has no exact [AppSpacing] token; [AppSpacing.sm] (8px) is used as the
/// nearest one rather than a hardcoded `10`.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    required this.message,
    this.title,
    this.onDismiss,
    this.dismissSemanticLabel,
    super.key,
  });

  /// Optional bold-weight-free heading, e.g. "Error". When omitted, only
  /// [message] is shown.
  final String? title;
  final String message;

  /// When non-null, a dismiss (×) affordance is shown and invokes this.
  final VoidCallback? onDismiss;

  /// Screen-reader label for the dismiss button (PRD §7.4 — every
  /// interactive element needs one). No `AppLocalizations` access at this
  /// layer (see `BrandAvatar`'s doc comment for the same rule), so the
  /// caller should pass a localized string; falls back to an English
  /// default only so an icon-only button is never silently unlabeled.
  final String? dismissSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.errorBg,
        border: Border.all(color: colors.errorBorder),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppTypography.label.copyWith(
                      color: colors.errorText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(
                  message,
                  style: AppTypography.caption.copyWith(
                    color: colors.errorText,
                  ),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              key: const Key('error_banner_dismiss_button'),
              icon: Icon(Icons.close, color: colors.errorText, size: 18),
              onPressed: onDismiss,
              tooltip: dismissSemanticLabel ?? 'Dismiss',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
