import 'package:flutter/material.dart';

import 'package:kelal_studio/core/theme/app_theme.dart';

/// A section-grouping card: `bgSurface` on `bgCanvas`, a soft shadow
/// derived from `textPrimary` at low opacity (not a new hardcoded color —
/// see mobile/CLAUDE.md's "never hardcode a hex/px value" rule; this reuses
/// the existing `textPrimary` token as a shadow tint, the same technique
/// `account_deleted_page.dart` already uses for its own overlay tint), and
/// `AppRadius.xl` for a softer corner than the `md` most components use —
/// deliberately a size up, since these are a screen's primary visual
/// containers, not incidental chips/fields.
///
/// Shared by `ComposerPage` and `SettingsPage` — both independently needed
/// "group related controls into a soft, bordered surface" and had started
/// duplicating the exact same `Container`/`BoxDecoration` recipe before
/// this was extracted; promote here rather than let a third page
/// re-duplicate it again.
class SoftCard extends StatelessWidget {
  const SoftCard({required this.child, this.padding, super.key});

  final Widget child;

  /// Defaults to [AppSpacing.lg] on every side. Pass e.g.
  /// [EdgeInsets.zero] when the child is a list of full-bleed rows that
  /// want their own internal padding instead (see `SettingsPage`'s rows).
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
