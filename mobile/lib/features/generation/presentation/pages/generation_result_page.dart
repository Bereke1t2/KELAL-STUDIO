import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/router/app_page_transitions.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/error_snack_bar.dart';
import 'package:kelal_studio/core/widgets/primary_button.dart';
import 'package:kelal_studio/core/widgets/quota_exceeded_dialog.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/pages/canvas_editor_page.dart';
import 'package:kelal_studio/features/generation/domain/entities/aspect_ratio.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_result.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/image_generation_bloc.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/image_generation_event.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/image_generation_state.dart';
import 'package:kelal_studio/features/generation/presentation/widgets/generation_result_view.dart';

/// Carried via `GoRouterState.extra` the same way `CanvasEditorPageArgs`/
/// `ExportPageArgs` are — `result`'s fields are all plain strings/lists so
/// this *could* round-trip through a URL in principle, but nothing links
/// to a specific past generation, so there's no reason to invent a URL
/// shape nobody needs; `extra` keeps this consistent with its siblings.
class GenerationResultPageArgs {
  const GenerationResultPageArgs({
    required this.result,
    required this.inputText,
  });

  final GenerationResult result;

  /// The idea text this result came from, snapshotted by `ComposerPage` at
  /// the moment it navigated here — seeds `DraftAutosaveCubit` via
  /// `CanvasEditorPageArgs.inputText` if "Create graphic" is tapped (PRD
  /// §10.5).
  final String inputText;
}

/// A completed [GenerationResult], on its own routed screen — reached via
/// `context.push('/generation-result', extra: GenerationResultPageArgs(...))`
/// once `GenerationBloc` emits `GenerationSuccess` (see `ComposerPage`'s
/// `BlocListener`) and left via the `AppBar`'s standard back button, which
/// returns to Compose with its idea/language/platform state untouched
/// (the composer form is still mounted underneath, just not visible).
///
/// This used to be inline content on `ComposerPage` itself — moved out to
/// its own screen so a result gets a full page rather than sharing space
/// with the composer form below the fold. Owns its own, **fresh**
/// `ImageGenerationBloc` (via `getIt`, not an instance shared with
/// `ComposerPage`) — simpler than what the inline version needed:
/// `ComposerPage` used to snapshot this result's captions into local
/// fields specifically to survive a second, concurrent text regeneration
/// on the still-visible composer form while a "Create graphic" request
/// for *this* result was in flight. That race can't happen here — this
/// page holds its own immutable `args.result`, and the composer form
/// underneath isn't interactive while this page covers it, so there's
/// nothing left to snapshot against.
class GenerationResultPage extends StatelessWidget {
  const GenerationResultPage({required this.args, super.key});

  final GenerationResultPageArgs args;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ImageGenerationBloc>(),
      child: _GenerationResultView(args: args),
    );
  }
}

class _GenerationResultView extends StatelessWidget {
  const _GenerationResultView({required this.args});

  final GenerationResultPageArgs args;

  /// Same mapping `ComposerPage._imageErrorMessage` used before this page
  /// existed — image-specific copy for `validationError`, since the idea
  /// text has already passed text-generation's own validation by the time
  /// a result (and this page) exists at all.
  String _imageErrorMessage(AppLocalizations l10n, ApiFailure failure) {
    return switch (failure.type) {
      ApiErrorType.validationError => l10n.generationErrorImageValidationError,
      ApiErrorType.providerTimeout => l10n.generationErrorProviderTimeout,
      ApiErrorType.malformedOutput => l10n.generationErrorMalformedOutput,
      ApiErrorType.network => l10n.generationErrorNetwork,
      ApiErrorType.unauthorized => l10n.generationErrorUnauthorized,
      ApiErrorType.moderationRefused => failure.message,
      ApiErrorType.quotaExceeded => failure.message,
      ApiErrorType.emailNotVerified => failure.message,
      ApiErrorType.notFound => l10n.generationErrorUnknown,
      ApiErrorType.accountLocked => l10n.generationErrorUnknown,
      ApiErrorType.unknown => l10n.generationErrorUnknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocListener<ImageGenerationBloc, ImageGenerationState>(
      listener: (context, state) {
        switch (state) {
          case ImageGenerationSuccess(:final scene):
            context.push(
              '/canvas-editor',
              extra: CanvasEditorPageArgs(
                scene: scene,
                captionEn: args.result.captionEn,
                captionAm: args.result.captionAm,
                inputText: args.inputText,
              ),
            );
          case ImageGenerationBrandKitRequired():
            showErrorSnackBar(
              context,
              l10n.composerImageGenerationBrandKitRequired,
            );
          case ImageGenerationFailure(:final failure)
              when failure.type == ApiErrorType.quotaExceeded:
            showQuotaExceededDialog(context, failure);
          case ImageGenerationFailure(:final failure):
            showErrorSnackBar(context, _imageErrorMessage(l10n, failure));
          case ImageGenerationInitial():
          case ImageGenerationInProgress():
            break;
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.generationResultTitle)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GenerationResultView(result: args.result),
              const SizedBox(height: AppSpacing.xl),
              BlocBuilder<ImageGenerationBloc, ImageGenerationState>(
                builder: (context, state) {
                  final isGenerating = state is ImageGenerationInProgress;
                  // Hero flight into CanvasEditorPage's AppBar title, tag
                  // shared via `heroCreateGraphicTag` — see its doc
                  // comment. Only meaningful mid-flight (while
                  // `ImageGenerationSuccess` is navigating away); harmless
                  // as a no-op wrapper the rest of the time.
                  return Hero(
                    tag: heroCreateGraphicTag,
                    child: PrimaryButton(
                      key: const Key('composer_create_graphic_button'),
                      label: l10n.composerCreateGraphicButton,
                      icon: Icons.auto_fix_high,
                      isLoading: isGenerating,
                      onPressed: isGenerating
                          ? null
                          : () => context.read<ImageGenerationBloc>().add(
                              ImageGenerationRequested(
                                captionEn: args.result.captionEn,
                                // Defaults to 1:1 — CanvasEditorPage owns
                                // the real ratio selector once inside the
                                // editor; this is only the seed ratio for
                                // the initial `/generate/image` call, not
                                // a user-facing choice made here.
                                aspectRatio: GenerationAspectRatio.oneToOne,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
