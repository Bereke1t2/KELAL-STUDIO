import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/core/render_engine/render_engine.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/app_bottom_sheet.dart';
import 'package:kelal_studio/core/widgets/error_snack_bar.dart';
import 'package:kelal_studio/core/widgets/primary_button.dart';
import 'package:kelal_studio/core/widgets/segmented_control.dart';
import 'package:kelal_studio/features/export/domain/entities/export_failure.dart';
import 'package:kelal_studio/features/export/presentation/bloc/export_bloc.dart';
import 'package:kelal_studio/features/export/presentation/bloc/export_event.dart';
import 'package:kelal_studio/features/export/presentation/bloc/export_state.dart';
import 'package:kelal_studio/features/export/presentation/cubit/export_overlay_seen_cubit.dart';

/// `/export`'s `state.extra` payload — bundles the (possibly user-edited)
/// [CanvasScene] together with both of the original generation's caption
/// strings.
///
/// **Contract-gap note (flagged per this branch's task, not silently
/// resolved):** `CanvasScene` itself carries no caption field (it's built
/// from decoded images/text layers, not the original `GenerationResult`),
/// so the two caption strings have to be threaded through the whole
/// composer -> image-generation -> canvas-editor -> export pipeline
/// separately from the scene. See `CanvasEditorPageArgs`
/// (`canvas_editor_page.dart`) and `ComposerPage`'s `ImageGenerationSuccess`
/// listener (`composer_page.dart`) for where that thread starts.
class ExportPageArgs {
  const ExportPageArgs({
    required this.scene,
    required this.captionEn,
    required this.captionAm,
  });

  final CanvasScene scene;
  final String captionEn;
  final String captionAm;
}

/// PRD §6.11's export/share screen — reached from `CanvasEditorPage`'s
/// Continue button (`/canvas-editor` -> `/export`). Offers: save the
/// rendered graphic to the device gallery, hand it to the OS Share Sheet,
/// and copy the caption text to the clipboard (never a programmatic paste
/// — the user pastes manually wherever they're posting, per PRD §6.11
/// explicitly).
class ExportPage extends StatelessWidget {
  const ExportPage({required this.args, super.key});

  final ExportPageArgs args;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<ExportBloc>()),
        BlocProvider(create: (_) => getIt<ExportOverlaySeenCubit>()),
      ],
      child: _ExportView(args: args),
    );
  }
}

class _ExportView extends StatefulWidget {
  const _ExportView({required this.args});

  final ExportPageArgs args;

  @override
  State<_ExportView> createState() => _ExportViewState();
}

class _ExportViewState extends State<_ExportView> {
  // Which of the two GenerationResult captions the Copy/Share actions use.
  //
  // OQ-EXPORT-1: PRD §6.11 doesn't say which caption language a single
  // "copy caption" affordance should default to, or whether the export
  // screen needs its own language choice at all. ComposerPage's own
  // EN/AM/Auto language toggle is local `State` private to that page (not
  // carried in GenerationResult or ImageGenerationSuccess), so by the time
  // this screen exists that choice is no longer in scope to "mirror" —
  // this resolves it with a local EN/AM toggle of its own (defaulting to
  // EN, this branch's task-instructed fallback) rather than silently
  // picking one caption with no way to switch. Flagged here per
  // mobile/.claude/skills/flutter-architecture/SKILL.md's standing rule
  // rather than resolved without comment.
  int _captionLanguageIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOverlay());
  }

  String get _selectedCaption => _captionLanguageIndex == 0
      ? widget.args.captionEn
      : widget.args.captionAm;

  Future<void> _maybeShowOverlay() async {
    if (!mounted) return;
    final cubit = context.read<ExportOverlaySeenCubit>();
    if (cubit.state) return;
    final l10n = AppLocalizations.of(context);
    await showAppBottomSheet<void>(
      context,
      sheet: AppBottomSheet(
        heading: l10n.exportFirstRunOverlayHeading,
        body: l10n.exportFirstRunOverlayBody,
        primaryLabel: l10n.exportFirstRunOverlayAction,
        onPrimaryPressed: () => Navigator.of(context).pop(),
      ),
    );
    // Marked seen once the sheet closes by *any* means — not only the
    // primary button — since `showAppBottomSheet` (`showModalBottomSheet`
    // under it) defaults to dismissible via scrim tap/swipe-down, and this
    // overlay's job (PRD §6.11: teach the long-press-to-paste step once)
    // is done the moment the user has seen it, whether they dismissed it
    // by reading it or by tapping past it. Re-showing it on every future
    // visit just because the user didn't happen to hit the button would
    // defeat the "once" in "first-run".
    cubit.markSeen();
  }

  Future<void> _copyCaption(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: _selectedCaption));
    if (!context.mounted) return;
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: colors.successBg,
        content: Text(
          l10n.exportCaptionCopiedMessage,
          style: AppTypography.bodySmall.copyWith(color: colors.successText),
        ),
      ),
    );
  }

  /// Maps every [ExportFailureType] to plain-language, localized copy —
  /// mirrors `ComposerPage._errorMessage`'s switch-on-`.type` pattern.
  /// `unknown` reuses `generationErrorUnknown` rather than a near-duplicate
  /// export-specific string with identical English text.
  String _errorMessage(AppLocalizations l10n, ExportFailureType type) {
    return switch (type) {
      ExportFailureType.galleryPermissionDenied =>
        l10n.exportGalleryPermissionDeniedMessage,
      ExportFailureType.galleryWriteFailed =>
        l10n.exportGalleryWriteFailedMessage,
      ExportFailureType.shareFailed => l10n.exportShareFailedMessage,
      ExportFailureType.unknown => l10n.generationErrorUnknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final scene = widget.args.scene;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportPageTitle)),
      body: BlocConsumer<ExportBloc, ExportState>(
        listener: (context, state) {
          switch (state) {
            case ExportGallerySaveSuccess():
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: colors.successBg,
                  content: Text(
                    l10n.exportGallerySaveSuccessMessage,
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.successText,
                    ),
                  ),
                ),
              );
            case ExportGallerySaveFailure(:final type):
              showErrorSnackBar(context, _errorMessage(l10n, type));
            case ExportShareFailure(:final type):
              showErrorSnackBar(context, _errorMessage(l10n, type));
            // Share success shows no snack bar of its own — the OS Share
            // Sheet appearing/dismissing is itself the user-visible
            // confirmation (see ExportState's doc comment).
            case ExportInitial():
            case ExportGallerySaveInProgress():
            case ExportShareInProgress():
            case ExportShareSuccess():
              break;
          }
        },
        builder: (context, state) {
          final isSaving = state is ExportGallerySaveInProgress;
          final isSharing = state is ExportShareInProgress;
          final bloc = context.read<ExportBloc>();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: scene.canvasSize.width / scene.canvasSize.height,
                  child: CustomPaint(
                    key: const Key('export_preview_paint'),
                    painter: CanvasScenePainter(scene),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  l10n.exportCaptionLanguageSectionLabel,
                  style: AppTypography.label.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSegmentedControl(
                  key: const Key('export_caption_language_toggle'),
                  labels: [
                    l10n.composerLanguageEnOption,
                    l10n.composerLanguageAmOption,
                  ],
                  selectedIndex: _captionLanguageIndex,
                  onChanged: (index) =>
                      setState(() => _captionLanguageIndex = index),
                ),
                const SizedBox(height: AppSpacing.xxl),
                PrimaryButton(
                  key: const Key('export_save_button'),
                  label: l10n.exportSaveButton,
                  isLoading: isSaving,
                  onPressed: (isSaving || isSharing)
                      ? null
                      : () => bloc.add(ExportGallerySaveRequested(scene)),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  key: const Key('export_share_button'),
                  label: l10n.exportShareButton,
                  isLoading: isSharing,
                  onPressed: (isSaving || isSharing)
                      ? null
                      : () => bloc.add(
                          ExportShareRequested(
                            scene: scene,
                            captionText: _selectedCaption,
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  key: const Key('export_copy_caption_button'),
                  onPressed: () => _copyCaption(context),
                  child: Text(l10n.exportCopyCaptionButton),
                ),
              ],
            ),
          );
        },
      ),
      backgroundColor: colors.bgCanvas,
    );
  }
}
