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
    this.textRemainingShortLabel,
    this.imageRemainingLabel,
    this.imageRemainingShortLabel,
    this.resetLabel,
    this.errorMessage,
    this.isWarning = false,
    this.loadingValue,
    super.key,
  }) : assert(
         status != QuotaBadgeStatus.loaded ||
             (textRemainingLabel != null &&
                 textRemainingShortLabel != null &&
                 imageRemainingLabel != null &&
                 imageRemainingShortLabel != null &&
                 resetLabel != null),
         'QuotaBadgeStatus.loaded requires textRemainingLabel, '
         'textRemainingShortLabel, imageRemainingLabel, '
         'imageRemainingShortLabel, and resetLabel',
       ),
       assert(
         status != QuotaBadgeStatus.error || errorMessage != null,
         'QuotaBadgeStatus.error requires errorMessage',
       );

  final QuotaBadgeStatus status;

  /// e.g. "3 of 10 text calls remaining today" — the full sentence, never
  /// shown directly (the badge is a single compact row, not a paragraph
  /// block). Surfaced as [textRemainingShortLabel]'s [Tooltip]/semantic
  /// label instead, so a screen reader or long-press still gets the whole
  /// sentence. Required when [status] is [QuotaBadgeStatus.loaded].
  final String? textRemainingLabel;

  /// e.g. "3/10 text" — what's actually painted on screen. Required when
  /// [status] is [QuotaBadgeStatus.loaded].
  final String? textRemainingShortLabel;

  /// Image-generation equivalent of [textRemainingLabel].
  final String? imageRemainingLabel;

  /// Image-generation equivalent of [textRemainingShortLabel].
  final String? imageRemainingShortLabel;

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
      // A single slim strip instead of three stacked full-sentence lines —
      // PRD §6.14 only asks that remaining quota be visible *before* a
      // generation attempt, not that this badge narrate the full sentence
      // on screen at all times. The full text/imageRemainingLabel
      // sentences still exist — each chip below carries one as its
      // Tooltip/Semantics label — so nothing here is actually less
      // accessible, just less tall. Wrap (not Row) so an unusually long
      // reset-time string on a narrow device reflows to a second line
      // instead of overflowing, rather than assuming everything always
      // fits one row.
      QuotaBadgeStatus.loaded => Container(
        key: const Key('quota_badge_loaded'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isWarning ? colors.warningBg : colors.bgSurfaceRaised,
          border: Border.all(
            color: isWarning ? colors.warningBorder : colors.borderSubtle,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xxs,
          children: [
            _QuotaChip(
              icon: Icons.edit_note_rounded,
              label: textRemainingShortLabel!,
              tooltip: textRemainingLabel!,
              color: isWarning ? colors.warningText : colors.textPrimary,
            ),
            _QuotaChip(
              icon: Icons.image_outlined,
              label: imageRemainingShortLabel!,
              tooltip: imageRemainingLabel!,
              color: isWarning ? colors.warningText : colors.textPrimary,
            ),
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

/// One "icon + short digits" stat inside [QuotaBadge]'s loaded row. Kept
/// private — this is purely [QuotaBadge]'s own internal layout unit, not a
/// reusable primitive anything else should reach for.
class _QuotaChip extends StatelessWidget {
  const _QuotaChip({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.color,
  });

  final IconData icon;
  final String label;

  /// The full sentence this chip's [label] compresses — shown on
  /// hover/long-press and read by a screen reader, so compressing the
  /// on-screen text never loses the detail, it's just not painted by
  /// default.
  final String tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xxs),
            Text(label, style: AppTypography.bodySmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
