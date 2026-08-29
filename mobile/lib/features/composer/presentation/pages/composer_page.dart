import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/app_text_field.dart';
import 'package:kelal_studio/core/widgets/error_banner.dart';
import 'package:kelal_studio/core/widgets/error_snack_bar.dart';
import 'package:kelal_studio/core/widgets/primary_button.dart';
import 'package:kelal_studio/core/widgets/quota_exceeded_dialog.dart';
import 'package:kelal_studio/core/widgets/segmented_control.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/pages/canvas_editor_page.dart';
import 'package:kelal_studio/features/generation/domain/entities/aspect_ratio.dart';
import 'package:kelal_studio/features/generation/domain/entities/content_platform.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_result.dart';
import 'package:kelal_studio/features/generation/domain/entities/input_language.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/generation_bloc.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/generation_event.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/generation_state.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/image_generation_bloc.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/image_generation_event.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/image_generation_state.dart';
import 'package:kelal_studio/features/generation/presentation/widgets/generation_result_view.dart';

/// The Idea Composer — PRD §6.2. Intended as `EmailVerificationGate`'s
/// `child` at the `/compose` route (see `core/router/app_router.dart`),
/// **not** a whole `Scaffold` of its own: the route already supplies the
/// `AppBar`/`QuotaStatusBadge` chrome around it, same contract
/// `EmailVerificationGate`'s own doc comment documents for its `child`.
///
/// **Deliberately owns `GenerationBloc` directly**, even though
/// "composer" and "generation" are two separate features in
/// `lib/features/`. Composer's only reason to exist is to feed a
/// generation request (see this branch's task: "composer's submit
/// actually delegates to generation") and this branch adds no separate
/// `/generate` route to host a standalone generation screen — so rather
/// than inventing a second screen with no route of its own, this page is
/// the single place both the composer form (local `StatefulWidget`
/// state — free text, language/platform toggles) and the generation
/// result (`GenerationBloc`-driven) live together. If a later branch adds
/// a reason to view/re-run a generation independently of composing a new
/// idea, that would be the point to split this into two routed screens.
///
/// Also owns `ImageGenerationBloc` (feat/render-engine-canvas-editor) for
/// the same reason: turning a successful text result into a graphic is a
/// composer-initiated action ("Create graphic" under `GenerationResultView`),
/// not a screen of its own — the real destination for that flow is
/// `CanvasEditorPage`, pushed at `/canvas-editor` once
/// `ImageGenerationSuccess` lands.
class ComposerPage extends StatelessWidget {
  const ComposerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<GenerationBloc>()),
        BlocProvider(create: (_) => getIt<ImageGenerationBloc>()),
      ],
      child: const _ComposerView(),
    );
  }
}

class _ComposerView extends StatefulWidget {
  const _ComposerView();

  @override
  State<_ComposerView> createState() => _ComposerViewState();
}

class _ComposerViewState extends State<_ComposerView> {
  final _ideaController = TextEditingController();

  // Ordered to match each AppSegmentedControl's label list below —
  // `selectedIndex` in, `_languages[index]`/`_platforms[index]` out.
  static const _languages = [
    InputLanguage.en,
    InputLanguage.am,
    InputLanguage.auto,
  ];
  static const _platforms = [
    ContentPlatform.instagram,
    ContentPlatform.tiktok,
    ContentPlatform.telegram,
  ];

  // Defaults to Auto — PRD §6.2 describes automatic language detection as
  // the composer's headline behavior ("Free-text input ... with automatic
  // language detection"), so that's the more representative default than
  // forcing an English- or Amharic-first assumption (see
  // mobile/.claude/skills/flutter-architecture/SKILL.md's "Idea Composer
  // input" open-question row — this default doesn't resolve that
  // question, it just avoids silently picking a side).
  int _languageIndex = 2;
  int _platformIndex = 0;

  String? _ideaError;

  // Snapshotted in `_createGraphic` at the moment "Create graphic" is
  // tapped, not re-read from `GenerationBloc`'s state when
  // `ImageGenerationSuccess` later lands (see `_createGraphic`'s doc
  // comment for why re-reading is unsafe).
  String _pendingGraphicCaptionEn = '';
  String _pendingGraphicCaptionAm = '';

  // OQ: `api_contract/openapi.yaml`'s `/generate/text` request schema
  // declares `input_text` as an unbounded `string` — no `maxLength`. A
  // pasted wall of text would otherwise go straight to a paid,
  // quota-consuming generation call with nothing in front of it but the
  // empty-string check in `_submit`. 500 is a conservative, clearly
  // client-side-only guess (a few sentences — comfortably more than a
  // social caption prompt needs) pending a real limit from the backend
  // contract; flagged here rather than silently assumed enforced
  // server-side.
  static const _maxIdeaLength = 500;

  @override
  void dispose() {
    _ideaController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) {
      setState(() => _ideaError = l10n.composerEmptyIdeaError);
      return;
    }
    setState(() => _ideaError = null);
    context.read<GenerationBloc>().add(
      GenerationRequested(
        inputText: idea,
        inputLanguage: _languages[_languageIndex],
        platform: _platforms[_platformIndex],
      ),
    );
  }

  /// Maps every non-`quotaExceeded` [ApiErrorType] to plain-language,
  /// app-interface-localized copy — mirrors `LoginPage`'s
  /// `errorType`-driven mapping in its `BlocConsumer` listener.
  /// `moderationRefused` is the one exception: per PRD §6.4 the backend
  /// already localizes that message to the *input* language, so it's
  /// shown verbatim rather than re-localized to the app's interface
  /// language — same reasoning `LoginState`'s doc comment gives.
  /// `quotaExceeded` never reaches this getter — it's handled by
  /// `showQuotaExceededDialog` in the `BlocListener` below instead.
  String _errorMessage(AppLocalizations l10n, ApiFailure failure) {
    return switch (failure.type) {
      ApiErrorType.providerTimeout => l10n.generationErrorProviderTimeout,
      ApiErrorType.malformedOutput => l10n.generationErrorMalformedOutput,
      ApiErrorType.validationError => l10n.generationErrorValidationError,
      ApiErrorType.network => l10n.generationErrorNetwork,
      ApiErrorType.unauthorized => l10n.generationErrorUnauthorized,
      ApiErrorType.moderationRefused => failure.message,
      ApiErrorType.quotaExceeded => failure.message,
      ApiErrorType.unknown => l10n.generationErrorUnknown,
    };
  }

  /// Same mapping as [_errorMessage] except `validationError`, which needs
  /// distinct copy here: by the time `/generate/image` can return that
  /// error, the idea text has already passed [GenerationBloc]'s own
  /// validation — `_errorMessage`'s "check your idea" copy would point at
  /// a field that isn't even the problem (see
  /// `generationErrorImageValidationError`'s ARB description).
  String _imageErrorMessage(AppLocalizations l10n, ApiFailure failure) {
    return failure.type == ApiErrorType.validationError
        ? l10n.generationErrorImageValidationError
        : _errorMessage(l10n, failure);
  }

  /// Snapshots [result]'s captions into [_pendingGraphicCaptionEn]/
  /// [_pendingGraphicCaptionAm] **before** dispatching the request —
  /// deliberately not left to be re-read from `GenerationBloc`'s state
  /// later when `ImageGenerationSuccess` lands. `ImageGenerationBloc`'s
  /// own request/decode span can run for a while (a real network call plus
  /// an image fetch+decode), and nothing prevents the user from firing a
  /// *second*, unrelated `GenerationRequested` (re-generating the idea
  /// text) on `GenerationBloc` while that's in flight — the "Create
  /// graphic" button's own disabled-while-`ImageGenerationInProgress`
  /// guard only stops a second *image* request, not a concurrent text one.
  /// If this method instead re-read `context.read<GenerationBloc>().state`
  /// inside the `ImageGenerationSuccess` listener, a text re-generation
  /// landing in that window would silently pair the *new* idea's captions
  /// with the graphic actually rendered from *this* one. Snapshotting here
  /// ties the captions to the specific tap that triggered this graphic,
  /// immune to whatever `GenerationBloc` does afterward.
  void _createGraphic(BuildContext context, GenerationResult result) {
    _pendingGraphicCaptionEn = result.captionEn;
    _pendingGraphicCaptionAm = result.captionAm;
    context.read<ImageGenerationBloc>().add(
      ImageGenerationRequested(
        captionEn: result.captionEn,
        // Defaults to 1:1 — CanvasEditorPage owns the real ratio selector
        // (AppSegmentedControl, `CanvasEditorAspectRatioChanged`) once
        // inside the editor; this is only the seed ratio for the initial
        // `/generate/image` call, not a user-facing choice made here.
        aspectRatio: GenerationAspectRatio.oneToOne,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    return MultiBlocListener(
      listeners: [
        BlocListener<GenerationBloc, GenerationState>(
          listenWhen: (previous, current) =>
              current is GenerationFailure &&
              current.failure.type == ApiErrorType.quotaExceeded,
          listener: (context, state) => showQuotaExceededDialog(
            context,
            (state as GenerationFailure).failure,
          ),
        ),
        BlocListener<ImageGenerationBloc, ImageGenerationState>(
          listener: (context, state) {
            switch (state) {
              case ImageGenerationSuccess(:final scene):
                // GenerationResult itself was never carried into
                // ImageGenerationBloc (only its English caption was — see
                // `_createGraphic` above), so both captions come from
                // `_pendingGraphicCaptionEn`/`_pendingGraphicCaptionAm`
                // instead — snapshotted in `_createGraphic` at the moment
                // this graphic's request was dispatched, not re-read from
                // `GenerationBloc`'s (possibly since-changed) current state
                // here. See `_createGraphic`'s doc comment for the race
                // this avoids.
                context.push(
                  '/canvas-editor',
                  extra: CanvasEditorPageArgs(
                    scene: scene,
                    captionEn: _pendingGraphicCaptionEn,
                    captionAm: _pendingGraphicCaptionAm,
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
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              key: const Key('composer_idea_field'),
              controller: _ideaController,
              label: l10n.composerIdeaLabel,
              maxLines: 5,
              minLines: 3,
              maxLength: _maxIdeaLength,
              errorText: _ideaError,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.composerLanguageSectionLabel,
              style: AppTypography.label.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppSegmentedControl(
              key: const Key('composer_language_toggle'),
              labels: [
                l10n.composerLanguageEnOption,
                l10n.composerLanguageAmOption,
                l10n.composerLanguageAutoOption,
              ],
              selectedIndex: _languageIndex,
              onChanged: (index) => setState(() => _languageIndex = index),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.composerPlatformSectionLabel,
              style: AppTypography.label.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppSegmentedControl(
              key: const Key('composer_platform_toggle'),
              labels: [
                l10n.composerPlatformInstagramOption,
                l10n.composerPlatformTiktokOption,
                l10n.composerPlatformTelegramOption,
              ],
              selectedIndex: _platformIndex,
              onChanged: (index) => setState(() => _platformIndex = index),
            ),
            const SizedBox(height: AppSpacing.xxl),
            BlocBuilder<GenerationBloc, GenerationState>(
              builder: (context, state) {
                final isGenerating = state is GenerationInProgress;
                return PrimaryButton(
                  key: const Key('composer_generate_button'),
                  label: l10n.composerGenerateButton,
                  isLoading: isGenerating,
                  onPressed: isGenerating ? null : () => _submit(context),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            BlocBuilder<GenerationBloc, GenerationState>(
              builder: (context, state) {
                return switch (state) {
                  GenerationInitial() ||
                  GenerationInProgress() => const SizedBox.shrink(),
                  GenerationSuccess(:final result) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GenerationResultView(result: result),
                      const SizedBox(height: AppSpacing.xl),
                      BlocBuilder<ImageGenerationBloc, ImageGenerationState>(
                        builder: (context, imageState) {
                          final isGenerating =
                              imageState is ImageGenerationInProgress;
                          return PrimaryButton(
                            key: const Key('composer_create_graphic_button'),
                            label: l10n.composerCreateGraphicButton,
                            isLoading: isGenerating,
                            onPressed: isGenerating
                                ? null
                                : () => _createGraphic(context, result),
                          );
                        },
                      ),
                    ],
                  ),
                  // quotaExceeded is surfaced via the dialog above, not an
                  // inline banner — showing both would be redundant.
                  GenerationFailure(:final failure)
                      when failure.type == ApiErrorType.quotaExceeded =>
                    const SizedBox.shrink(),
                  GenerationFailure(:final failure) => ErrorBanner(
                    key: const Key('composer_generation_error_banner'),
                    message: _errorMessage(l10n, failure),
                  ),
                };
              },
            ),
          ],
        ),
      ),
    );
  }
}
