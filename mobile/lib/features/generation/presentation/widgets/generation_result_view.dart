import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_result.dart';

/// Renders a completed [GenerationResult]: English caption, Amharic
/// caption, call to action, and hashtags, each with its own
/// copy-to-clipboard action (PRD's generation surface is meant to feed a
/// user's own paste-into-the-real-app workflow, not just be read on
/// screen). Feature-owned (not `core/widgets`) since it depends directly
/// on the `GenerationResult` domain entity — same "dumb but
/// domain-typed" tier as `ColorSwatchPicker`
/// (`features/brand_kit/presentation/widgets/`), one step below the fully
/// generic `core/widgets` primitives it's built from.
///
/// No shared clipboard helper existed anywhere in this codebase before
/// this branch (checked: no `Clipboard` usage under `lib/`) — this uses
/// `package:flutter/services.dart` directly, per this branch's task note
/// that doing so ad hoc here is fine since `features/export` (a later
/// branch) doesn't exist yet to own a shared helper.
class GenerationResultView extends StatelessWidget {
  const GenerationResultView({required this.result, super.key});

  final GenerationResult result;

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: colors.successBg,
        content: Text(
          AppLocalizations.of(context).generationCopiedMessage(label),
          style: AppTypography.bodySmall.copyWith(color: colors.successText),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final hashtagsValue = result.hashtags
        .map((tag) => tag.startsWith('#') ? tag : '#$tag')
        .join(' ');

    return Column(
      key: const Key('generation_result_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // PRD §6.2's fallback path (see GenerationResult.isFallback's doc
        // comment) is deliberately surfaced, not hidden — a user editing
        // and posting this content should know it's a saved template, not
        // a fresh generation for their specific idea.
        if (result.isFallback) ...[
          Container(
            key: const Key('generation_fallback_notice'),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.infoBg,
              border: Border.all(color: colors.infoBorder),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              l10n.generationFallbackNotice,
              style: AppTypography.caption.copyWith(color: colors.infoText),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _CopyableField(
          fieldId: 'generation_result_caption_en',
          label: l10n.generationCaptionEnLabel,
          value: result.captionEn,
          onCopy: () =>
              _copy(context, l10n.generationCaptionEnLabel, result.captionEn),
        ),
        const SizedBox(height: AppSpacing.lg),
        _CopyableField(
          fieldId: 'generation_result_caption_am',
          label: l10n.generationCaptionAmLabel,
          value: result.captionAm,
          onCopy: () =>
              _copy(context, l10n.generationCaptionAmLabel, result.captionAm),
        ),
        const SizedBox(height: AppSpacing.lg),
        _CopyableField(
          fieldId: 'generation_result_cta',
          label: l10n.generationCallToActionLabel,
          value: result.callToAction,
          onCopy: () => _copy(
            context,
            l10n.generationCallToActionLabel,
            result.callToAction,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _CopyableField(
          fieldId: 'generation_result_hashtags',
          label: l10n.generationHashtagsLabel,
          value: hashtagsValue,
          onCopy: () =>
              _copy(context, l10n.generationHashtagsLabel, hashtagsValue),
        ),
      ],
    );
  }
}

class _CopyableField extends StatelessWidget {
  const _CopyableField({
    required this.fieldId,
    required this.label,
    required this.value,
    required this.onCopy,
  });

  /// Snake-case id used to build both this field's own [Key] and its copy
  /// button's — kept as a plain string (not a `Key` param) so the two
  /// derived keys stay legible (`generation_result_caption_en_copy_button`)
  /// instead of nesting one `Key`'s `toString()` inside another.
  final String fieldId;
  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: Key(fieldId),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.bgSurfaceRaised,
        border: Border.all(color: colors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.label.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  style: AppTypography.body.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('${fieldId}_copy_button'),
            icon: Icon(Icons.copy, color: colors.textSecondary, size: 20),
            tooltip: AppLocalizations.of(context).generationCopyTooltip(label),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
