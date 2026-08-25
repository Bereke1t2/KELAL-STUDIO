import 'package:flutter/material.dart';

import 'package:kelal_studio/core/theme/app_theme.dart';

/// Which of the four Figma-documented states [BrandAvatar] is in — Figma
/// `Components / Avatar & Logo Tile`, node `48:2`: "Has Logo" (`48:6`),
/// "Initial Fallback" (`48:9`), "Uploading" (`48:13`), "Error" (`48:18`).
enum BrandAvatarStatus { hasLogo, initialFallback, uploading, error }

/// Business-logo preview tile used in Brand Kit setup/settings — a 72x72
/// rounded square (not a circle, despite "avatar" in the task naming —
/// Figma's own component is square/`radius-md`, matching a logo tile
/// rather than a person-avatar circle) that swaps content by
/// [BrandAvatarStatus], with a caption underneath for every state.
///
/// [caption] is a required parameter rather than a hardcoded English
/// string (Figma shows "Uploaded" / "No logo yet" / "Uploading…" / an
/// error message) — this is a `core/widgets` presentational component
/// with no `AppLocalizations` access, so per `mobile/CLAUDE.md`'s
/// localization rule the caller (which has l10n context) supplies the
/// already-localized text rather than this widget baking in English.
///
/// The Figma "Uploading" state uses a rotating-ring SVG asset; substituted
/// here with [CircularProgressIndicator] for the same reason as
/// `LoadingIndicator` (no SVG asset pipeline in this codebase — see
/// `flutter-design-system/SKILL.md`).
class BrandAvatar extends StatelessWidget {
  const BrandAvatar({
    required this.status,
    required this.caption,
    this.logo,
    this.initial,
    this.uploadProgress,
    super.key,
  }) : assert(
         status != BrandAvatarStatus.hasLogo || logo != null,
         'BrandAvatarStatus.hasLogo requires a logo image',
       ),
       assert(
         status != BrandAvatarStatus.initialFallback || initial != null,
         'BrandAvatarStatus.initialFallback requires an initial',
       );

  final BrandAvatarStatus status;

  /// Localized status text shown below the tile for every state.
  final String caption;

  /// The uploaded logo image, required when [status] is
  /// [BrandAvatarStatus.hasLogo].
  final Widget? logo;

  /// A single business-name letter (may be Amharic, e.g. "ቀ" in the Figma
  /// pull), required when [status] is [BrandAvatarStatus.initialFallback].
  final String? initial;

  /// Forwarded to the uploading ring's `CircularProgressIndicator.value`.
  /// Left `null` (indeterminate) for real usage; golden tests pin a fixed
  /// value so `pumpAndSettle` doesn't hang on a never-settling animation
  /// — see the equivalent note on `LoadingIndicator`.
  final double? uploadProgress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: switch (status) {
            BrandAvatarStatus.hasLogo => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: ColoredBox(color: colors.bgDisabled, child: logo),
            ),
            BrandAvatarStatus.initialFallback => Container(
              decoration: BoxDecoration(
                color: colors.bgBrandSubtle,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: Text(
                initial!,
                style: AppTypography.title.copyWith(
                  color: colors.primaryDefault,
                ),
              ),
            ),
            BrandAvatarStatus.uploading => Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colors.primaryDefault,
                value: uploadProgress,
              ),
            ),
            BrandAvatarStatus.error => Container(
              decoration: BoxDecoration(
                color: colors.errorBg,
                border: Border.all(color: colors.errorBorder),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(
            color: status == BrandAvatarStatus.error
                ? colors.errorText
                : colors.textTertiary,
          ),
        ),
      ],
    );
  }
}
