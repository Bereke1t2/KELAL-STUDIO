/// Modal shells — Figma `Components / Modal & Sheet`, node `42:2`, which
/// documents two sibling patterns: a bottom sheet ("Bottom Sheet —
/// Confirm Delete", node `42:6`) and a centered dialog ("Centered Dialog
/// — Fatal Error", node `42:15`). Both are built here since Figma groups
/// them as one component family and share the same action-button tokens;
/// the task's file-naming choice ("`app_bottom_sheet.dart` *or*
/// `app_dialog.dart`") is resolved by keeping the bottom sheet name for
/// the file and covering the dialog shape as a second export.
///
/// Both action buttons use [AppSpacing.minTapTarget] (48px) rather than
/// the dialog's literal Figma height (44px for "Retry") — the design
/// system's own accessibility NFR ("min 44-48px tap target") makes 48 the
/// documented floor, so it wins over the one-off pixel value.
library;

import 'package:flutter/material.dart';

import 'package:kelal_studio/core/theme/app_theme.dart';

/// Bottom-sheet shell with a grabber, heading, body, and one or two
/// stacked actions — Figma node `42:6`.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    required this.heading,
    required this.body,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.isDestructive = false,
    super.key,
  });

  final String heading;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;

  /// e.g. "Keep Draft" / "Cancel" — a lower-emphasis text action below
  /// the primary one.
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  /// Renders [primaryLabel]'s button in
  /// [AppColors.interactiveDestructiveDefault] (e.g. "Delete Draft")
  /// instead of the themed brand primary color.
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        bottom: AppSpacing.xxxl,
      ),
      decoration: BoxDecoration(
        color: colors.bgSurfaceRaised,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xl),
          topRight: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderStrong,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
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
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            key: const Key('app_bottom_sheet_primary_button'),
            style: isDestructive
                ? ElevatedButton.styleFrom(
                    backgroundColor: colors.interactiveDestructiveDefault,
                    foregroundColor: colors.bgSurface,
                  )
                : null,
            onPressed: onPrimaryPressed,
            child: Text(primaryLabel),
          ),
          if (secondaryLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: AppSpacing.minTapTarget,
              child: TextButton(
                key: const Key('app_bottom_sheet_secondary_button'),
                onPressed: onSecondaryPressed,
                child: Text(secondaryLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Centered dialog shell with an icon, heading, body, and one action —
/// Figma node `42:15`.
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.icon,
    required this.heading,
    required this.body,
    required this.actionLabel,
    required this.onActionPressed,
    super.key,
  });

  final IconData icon;
  final String heading;
  final String body;
  final String actionLabel;
  final VoidCallback onActionPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: colors.bgSurfaceRaised,
        border: Border.all(color: colors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: colors.errorBorder),
          const SizedBox(height: AppSpacing.md),
          Text(
            heading,
            textAlign: TextAlign.center,
            style: AppTypography.title.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('app_dialog_action_button'),
              onPressed: onActionPressed,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// Presents [sheet] (typically an [AppBottomSheet]) as a modal bottom
/// sheet with a transparent host background, so the sheet's own
/// top-rounded [BoxDecoration] shows through cleanly.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required Widget sheet,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => sheet,
  );
}

/// Presents [dialog] (typically an [AppDialog]) as a centered modal
/// dialog with a transparent host background.
Future<T?> showAppDialog<T>(BuildContext context, {required Widget dialog}) {
  return showDialog<T>(
    context: context,
    builder: (_) => Dialog(backgroundColor: Colors.transparent, child: dialog),
  );
}
