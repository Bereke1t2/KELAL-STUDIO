import 'package:flutter/material.dart';

import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/loading_indicator.dart';

/// Which of [QuotaBadge]'s three states it's rendering.
enum QuotaBadgeStatus { loading, loaded, error }

/// Compact "remaining quota" indicator — meant to sit at the top of the
/// Compose screen so remaining quota is visible *before* a generation is
/// attempted, not only surfaced on refusal (PRD §6.14: "is remaining quota
/// visible before generation is attempted"). A genuinely reusable
/// cross-feature primitive (any generation surface can drop this in), so
/// it lives alongside `PrimaryButton`/`ErrorBanner` here in `core/widgets`
/// rather than under `features/quota/presentation/widgets` — unlike
/// `brand_kit`'s screen-specific pieces, this isn't tied to one screen.
///
/// **Deliberately "dumb"**, mirroring `BrandAvatar`/`ErrorBanner`: no
/// `AppLocalizations`, no `Quota` domain entity, no `QuotaBloc` import
/// here. `core/` must never import from `features/**` (see
/// mobile/.claude/skills/flutter-architecture/SKILL.md's layering rule) —
/// a `Quota`-typed or Bloc-aware badge would violate that directly. Every
/// piece of text is pre-localized/pre-formatted by the caller; see
/// `features/quota/presentation/widgets/quota_status_badge.dart` for the
/// feature-owned wrapper that reads `QuotaBloc`/`Quota` and supplies these
/// primitives — same split `BrandAvatar` (dumb) / `_BrandKitForm` (smart)
/// already uses.
class QuotaBadge extends StatelessWidget {
  const QuotaBadge({
    required this.status,
    this.textRemainingLabel,
    this.imageRemainingLabel,
    this.resetLabel,
    this.errorMessage,
    this.isWarning = false,
    this.loadingValue,
    super.key,
  }) : assert(
         status != QuotaBadgeStatus.loaded ||
             (textRemainingLabel != null &&
                 imageRemainingLabel != null &&
                 resetLabel != null),
         'QuotaBadgeStatus.loaded requires textRemainingLabel, '
         'imageRemainingLabel, and resetLabel',
       ),
       assert(
         status != QuotaBadgeStatus.error || errorMessage != null,
         'QuotaBadgeStatus.error requires errorMessage',
       );

  final QuotaBadgeStatus status;

  /// e.g. "3 of 10 text calls remaining today". Required when [status] is
  /// [QuotaBadgeStatus.loaded].
  final String? textRemainingLabel;

  /// Image-generation equivalent of [textRemainingLabel].
  final String? imageRemainingLabel;

  /// e.g. "Resets at 6:00 PM". Required when [status] is
  /// [QuotaBadgeStatus.loaded].
  final String? resetLabel;

  /// Plain-language failure message. Required when [status] is
  /// [QuotaBadgeStatus.error].
  final String? errorMessage;

  /// When true, renders the loaded state in [AppColors.warningBg]/
  /// `warningBorder`/`warningText` instead of the neutral surface — the
  /// caller decides "near/at the limit" (it needs the raw `Quota` numbers,
  /// which this widget deliberately never sees).
  final bool isWarning;

  /// Forwarded to the loading spinner's `CircularProgressIndicator.value`.
  /// Left `null` (indeterminate) for real usage; golden tests pin a fixed
  /// value so `pumpAndSettle` doesn't hang on a never-settling animation
  /// — see the equivalent note on `LoadingIndicator`/`PrimaryButton`.
  final double? loadingValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return switch (status) {
      QuotaBadgeStatus.loading => Container(
        key: const Key('quota_badge_loading'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.bgSurfaceRaised,
          border: Border.all(color: colors.borderSubtle),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: LoadingIndicator(size: 18, value: loadingValue),
        ),
      ),
      QuotaBadgeStatus.error => Container(
        key: const Key('quota_badge_error'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.errorBg,
          border: Border.all(color: colors.errorBorder),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          errorMessage!,
          style: AppTypography.caption.copyWith(color: colors.errorText),
        ),
      ),
      QuotaBadgeStatus.loaded => Container(
        key: const Key('quota_badge_loaded'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isWarning ? colors.warningBg : colors.bgSurfaceRaised,
          border: Border.all(
            color: isWarning ? colors.warningBorder : colors.borderSubtle,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              textRemainingLabel!,
              style: AppTypography.bodySmall.copyWith(
                color: isWarning ? colors.warningText : colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              imageRemainingLabel!,
              style: AppTypography.bodySmall.copyWith(
                color: isWarning ? colors.warningText : colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              resetLabel!,
              style: AppTypography.caption.copyWith(
                color: isWarning ? colors.warningText : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    };
  }
}
