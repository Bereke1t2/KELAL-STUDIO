import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/app_text_field.dart';
import 'package:kelal_studio/core/widgets/error_banner.dart';
import 'package:kelal_studio/core/widgets/primary_button.dart';
import 'package:kelal_studio/core/widgets/quota_exceeded_dialog.dart';
import 'package:kelal_studio/core/widgets/segmented_control.dart';
import 'package:kelal_studio/core/widgets/soft_card.dart';
import 'package:kelal_studio/features/generation/domain/entities/content_platform.dart';
import 'package:kelal_studio/features/generation/domain/entities/input_language.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/generation_bloc.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/generation_event.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/generation_state.dart';
import 'package:kelal_studio/features/generation/presentation/pages/generation_result_page.dart';

/// The Idea Composer — PRD §6.2. Intended as `EmailVerificationGate`'s
/// `child` at the `/compose` route (see `core/router/app_router.dart`),
/// **not** a whole `Scaffold` of its own: the route already supplies the
/// `AppBar`/`QuotaStatusBadge` chrome around it, same contract
/// `EmailVerificationGate`'s own doc comment documents for its `child`.
///
/// **Deliberately owns `GenerationBloc` directly**, even though
/// "composer" and "generation" are two separate features in
/// `lib/features/`. Composer's only reason to exist is to feed a
/// generation request, and there's no separate route hosting a
/// standalone "just submit an idea" screen — so rather than inventing a
/// second screen for that, this page is the one place the composer form
/// (local `StatefulWidget` state — free text, language/platform toggles)
/// lives.
///
/// A completed result, on the other hand, **does** get its own screen —
/// `GenerationResultPage`, pushed at `/generation-result` once
/// `GenerationBloc` emits `GenerationSuccess` (see the `BlocListener`
/// below). That page owns `ImageGenerationBloc` and the "Create graphic"
/// action itself; this page doesn't hold a result once one exists, only
/// the state needed to request one.
class ComposerPage extends StatelessWidget {
  const ComposerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<GenerationBloc>(),
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

  // Drives a one-shot fade/slide-in on first build — purely decorative
  // (see build()'s AnimatedOpacity/AnimatedSlide), so a plain bool flipped
  // one frame after initState is enough; no AnimationController needed
  // since nothing here ever needs to reverse, replay, or be driven by
  // gesture/scroll.
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
  }

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
      // `/generate/*` gates on a verified email before any provider work
      // (PRD §6.1) — ApiExceptionMapper already produces plain, actionable
      // copy for this ("Please verify your email to continue."), same
      // reasoning as moderationRefused/quotaExceeded passing `.message`
      // straight through above.
      ApiErrorType.emailNotVerified => failure.message,
      // Not actually reachable from `/generate/*` today (notFound has no
      // meaning here; accountLocked is a login-only lockout) — handled for
      // exhaustiveness, not because either is expected.
      ApiErrorType.notFound => l10n.generationErrorUnknown,
      ApiErrorType.accountLocked => l10n.generationErrorUnknown,
      ApiErrorType.unknown => l10n.generationErrorUnknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    return BlocListener<GenerationBloc, GenerationState>(
      listener: (context, state) {
        switch (state) {
          case GenerationSuccess(:final result):
            // Pushed rather than rendered inline — see this page's own
            // doc comment for why a completed result gets its own screen
            // now. `context.read` (not the `result` destructured above
            // alone) isn't needed here since `_ideaController` is local
            // state, not Bloc state — snapshotting the idea text at the
            // moment of this specific success, same as before this page
            // existed, still matters: the user could keep typing while
            // this push is in flight (unlikely, but the snapshot costs
            // nothing and removes the question).
            context.push(
              '/generation-result',
              extra: GenerationResultPageArgs(
                result: result,
                inputText: _ideaController.text.trim(),
              ),
            );
          case GenerationFailure(:final failure)
              when failure.type == ApiErrorType.quotaExceeded:
            showQuotaExceededDialog(context, failure);
          case GenerationInitial():
          case GenerationInProgress():
          case GenerationFailure():
            break;
        }
      },
      child: Builder(
        builder: (context) {
          // A one-shot, respectful entrance: skipped entirely (duration
          // zero) when the platform/OS asks for reduced motion, rather
          // than every screen deciding this independently — see
          // `flutter-review-checklist`'s edge-case guidance and this app's
          // established "delight without a new dependency" pattern from
          // branch 13's motion-polish pass (Hero/AnimatedAlign/CustomPainter,
          // no animation package).
          final reduceMotion = MediaQuery.of(context).disableAnimations;
          final entranceDuration = Duration(
            milliseconds: reduceMotion ? 0 : 320,
          );
          return AnimatedSlide(
            duration: entranceDuration,
            curve: Curves.easeOutCubic,
            offset: _entered ? Offset.zero : const Offset(0, 0.03),
            child: AnimatedOpacity(
              duration: entranceDuration,
              curve: Curves.easeOut,
              opacity: _entered ? 1 : 0,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                  AppSpacing.xxxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SoftCard(
                      child: AppTextField(
                        key: const Key('composer_idea_field'),
                        controller: _ideaController,
                        label: l10n.composerIdeaLabel,
                        maxLines: 5,
                        minLines: 3,
                        maxLength: _maxIdeaLength,
                        errorText: _ideaError,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionHeader(
                            icon: Icons.translate_outlined,
                            label: l10n.composerLanguageSectionLabel,
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
                            onChanged: (index) =>
                                setState(() => _languageIndex = index),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Divider(color: colors.borderSubtle, height: 1),
                          const SizedBox(height: AppSpacing.lg),
                          _SectionHeader(
                            icon: Icons.share_outlined,
                            label: l10n.composerPlatformSectionLabel,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppSegmentedControl(
                            key: const Key('composer_platform_toggle'),
                            labels: [
                              l10n.composerPlatformInstagramOption,
                              l10n.composerPlatformTiktokOption,
                              l10n.composerPlatformTelegramOption,
                            ],
                            icons: const [
                              Icons.camera_alt_outlined,
                              Icons.music_note_outlined,
                              Icons.send_outlined,
                            ],
                            selectedIndex: _platformIndex,
                            onChanged: (index) =>
                                setState(() => _platformIndex = index),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    BlocBuilder<GenerationBloc, GenerationState>(
                      builder: (context, state) {
                        final isGenerating = state is GenerationInProgress;
                        return PrimaryButton(
                          key: const Key('composer_generate_button'),
                          label: l10n.composerGenerateButton,
                          icon: Icons.auto_awesome,
                          isLoading: isGenerating,
                          onPressed: isGenerating
                              ? null
                              : () => _submit(context),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // A completed result no longer renders here — it
                    // navigates to GenerationResultPage instead (see the
                    // BlocListener above), so GenerationSuccess is handled
                    // there, not in this switch. Only a failure worth
                    // seeing *on this page* — where retrying is the
                    // obvious next action — stays inline;
                    // quotaExceeded is surfaced via the dialog in the
                    // listener above instead, not this banner, since
                    // showing both would be redundant.
                    BlocBuilder<GenerationBloc, GenerationState>(
                      builder: (context, state) {
                        return switch (state) {
                          GenerationInitial() ||
                          GenerationInProgress() ||
                          GenerationSuccess() => const SizedBox.shrink(),
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
            ),
          );
        },
      ),
    );
  }
}

/// Small icon + label eyebrow above a [SoftCard] section — "Language"/
/// "Platform" are genuinely two different settings, not decoration, so a
/// distinguishing icon per header is meaningful, not merely decorative
/// (see the "structure is information" guidance this app's other design
/// docs point at). Kept private/composer-local rather than promoted to
/// `core/widgets` — this exact icon+label-in-a-Row shape isn't reused
/// anywhere else in the app yet (unlike the card container itself, see
/// `SoftCard`'s own doc comment for why that one was promoted).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.primaryDefault),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.label.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}
