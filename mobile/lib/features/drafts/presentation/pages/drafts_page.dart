import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/app_bottom_sheet.dart';
import 'package:kelal_studio/core/widgets/empty_state.dart';
import 'package:kelal_studio/core/widgets/error_snack_bar.dart';
import 'package:kelal_studio/core/widgets/skeleton_loader.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/pages/canvas_editor_page.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';
import 'package:kelal_studio/features/drafts/presentation/bloc/drafts_list_bloc.dart';
import 'package:kelal_studio/features/drafts/presentation/bloc/drafts_list_event.dart';
import 'package:kelal_studio/features/drafts/presentation/bloc/drafts_list_state.dart';
import 'package:kelal_studio/features/drafts/presentation/cubit/drafts_disclosure_seen_cubit.dart';
import 'package:kelal_studio/features/reminders/domain/entities/reminder_failure.dart';
import 'package:kelal_studio/features/reminders/presentation/utils/pick_reminder_date_time.dart';

const _snippetMaxLength = 80;

String _snippet(String text) {
  final trimmed = text.trim();
  if (trimmed.length <= _snippetMaxLength) return trimmed;
  return '${trimmed.substring(0, _snippetMaxLength)}…';
}

/// Relative "last saved" copy, hand-rolled from a plain `DateTime`
/// difference rather than a `timeago`-style package — `intl` (already
/// pinned in `pubspec.yaml`, used elsewhere for absolute formatting, e.g.
/// `showQuotaExceededDialog`'s `DateFormat.jm()`) has no built-in relative-
/// time helper, and adding a new dependency for four simple buckets isn't
/// justified (see mobile/CLAUDE.md's "don't add a dependency unless
/// confirmed genuinely unavailable" rule) — flagged in this branch's report
/// rather than silently pulled in.
String _relativeSavedLabel(AppLocalizations l10n, DateTime lastSavedAt) {
  final diff = DateTime.now().toUtc().difference(lastSavedAt.toUtc());
  if (diff.inMinutes < 1) return l10n.draftsLastSavedJustNow;
  if (diff.inHours < 1) return l10n.draftsLastSavedMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.draftsLastSavedHoursAgo(diff.inHours);
  return l10n.draftsLastSavedDaysAgo(diff.inDays);
}

/// PRD §10.5's local Drafts list — replaces the `/drafts` route's
/// `ComingSoonPage` placeholder (see `core/router/app_router.dart`).
class DraftsPage extends StatelessWidget {
  const DraftsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<DraftsListBloc>()),
        BlocProvider(create: (_) => getIt<DraftsDisclosureSeenCubit>()),
      ],
      child: const _DraftsView(),
    );
  }
}

class _DraftsView extends StatefulWidget {
  const _DraftsView();

  @override
  State<_DraftsView> createState() => _DraftsViewState();
}

class _DraftsViewState extends State<_DraftsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDisclosure());
  }

  /// PRD §6.10: first time the Drafts tab is opened, disclose that
  /// uninstalling the app destroys all local drafts (they're device-local
  /// only — no server sync, see mobile/CLAUDE.md's decisions log). Mirrors
  /// `ExportPage._maybeShowOverlay`'s exact pattern
  /// (`ExportOverlaySeenCubit`) — see `DraftsDisclosureSeenCubit`'s own
  /// doc comment.
  Future<void> _maybeShowDisclosure() async {
    if (!mounted) return;
    final cubit = context.read<DraftsDisclosureSeenCubit>();
    if (cubit.state) return;
    final l10n = AppLocalizations.of(context);
    await showAppBottomSheet<void>(
      context,
      sheet: AppBottomSheet(
        heading: l10n.draftsDisclosureHeading,
        body: l10n.draftsDisclosureBody,
        primaryLabel: l10n.draftsDisclosureAction,
        onPrimaryPressed: () => Navigator.of(context).pop(),
      ),
    );
    // Marked seen once the sheet closes by any means — same reasoning
    // `ExportPage._maybeShowOverlay` documents: the disclosure's job is
    // done the moment it's been shown once, not gated on which exact
    // dismissal path the user took.
    cubit.markSeen();
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showAppBottomSheet<bool>(
      context,
      sheet: AppBottomSheet(
        heading: l10n.draftsDeleteConfirmHeading,
        body: l10n.draftsDeleteConfirmBody,
        primaryLabel: l10n.draftsDeleteConfirmAction,
        onPrimaryPressed: () => Navigator.of(context).pop(true),
        secondaryLabel: l10n.cancelLabel,
        onSecondaryPressed: () => Navigator.of(context).pop(false),
        isDestructive: true,
      ),
    );
    return confirmed ?? false;
  }

  /// Drives the "Remind me" card action end to end: picks a date/time
  /// (`pickReminderDateTimeUtc`), then dispatches `DraftReminderRequested`
  /// with already-localized notification copy — see that event's doc
  /// comment for why the strings travel down as plain args rather than
  /// being resolved deeper in the stack.
  Future<void> _requestReminder(BuildContext context, Draft draft) async {
    final scheduledAtUtc = await pickReminderDateTimeUtc(context);
    if (scheduledAtUtc == null || !context.mounted) return;

    final l10n = AppLocalizations.of(context);
    context.read<DraftsListBloc>().add(
      DraftReminderRequested(
        localId: draft.localId,
        scheduledAtUtc: scheduledAtUtc,
        notificationTitle: l10n.remindersNotificationTitle,
        notificationBody: l10n.remindersNotificationBody,
      ),
    );
  }

  void _showReminderResultSnackBar(
    BuildContext context,
    AppLocalizations l10n,
    Result<Failure, void> result,
  ) {
    final colors = context.colors;
    result.when(
      ok: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: colors.successBg,
            content: Text(
              l10n.remindersScheduledSuccessMessage,
              style: AppTypography.bodySmall.copyWith(
                color: colors.successText,
              ),
            ),
          ),
        );
      },
      err: (failure) {
        final message = failure is ReminderPermissionDeniedFailure
            ? l10n.remindersPermissionDeniedMessage
            : l10n.generationErrorUnknown;
        showErrorSnackBar(context, message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgCanvas,
      // AppBar title consistent with the bottom-nav tab it lives under —
      // same convention BrandKitPage/SettingsPage each follow.
      appBar: AppBar(title: Text(l10n.navDraftsLabel)),
      body: MultiBlocListener(
        listeners: [
          BlocListener<DraftsListBloc, DraftsListState>(
            listenWhen: (previous, current) {
              if (current is! DraftsListLoaded ||
                  current.resumedScene == null) {
                return false;
              }
              return previous is! DraftsListLoaded ||
                  previous.resumedScene != current.resumedScene;
            },
            listener: (context, state) {
              final loaded = state as DraftsListLoaded;
              final scene = loaded.resumedScene!;
              final draft = loaded.resumedDraft!;
              // Resuming a draft only ever carries `inputText` forward —
              // the original AI-generated captions
              // (`GenerationResult.captionEn`/`captionAm`) are **not**
              // part of PRD §10.5's draft schema, so they can't be
              // recovered here. A real, known gap: continuing a draft
              // into `/export` later will show empty captions rather
              // than the ones that were showing when the draft was
              // saved. See `CanvasEditorPageArgs`'s doc comment for the
              // same note from the other side of this thread.
              context.push(
                '/canvas-editor',
                extra: CanvasEditorPageArgs(
                  scene: scene,
                  captionEn: '',
                  captionAm: '',
                  inputText: draft.inputText,
                  brandKitId: draft.brandKitId,
                ),
              );
            },
          ),
          BlocListener<DraftsListBloc, DraftsListState>(
            listenWhen: (previous, current) {
              if (current is! DraftsListLoaded ||
                  current.reminderResult == null) {
                return false;
              }
              return previous is! DraftsListLoaded ||
                  previous.reminderResult != current.reminderResult;
            },
            listener: (context, state) {
              final loaded = state as DraftsListLoaded;
              _showReminderResultSnackBar(
                context,
                l10n,
                loaded.reminderResult!,
              );
            },
          ),
        ],
        child: BlocBuilder<DraftsListBloc, DraftsListState>(
          builder: (context, state) {
            if (state is DraftsListLoading) {
              return const _DraftsListSkeleton();
            }
            final loaded = state as DraftsListLoaded;
            if (loaded.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: EmptyState(
                    icon: Icons.drafts_outlined,
                    heading: l10n.draftsEmptyHeading,
                    body: l10n.draftsEmptyBody,
                  ),
                ),
              );
            }

            return ListView.separated(
              key: const Key('drafts_list'),
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: loaded.drafts.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final draft = loaded.drafts[index];
                return _DraftCard(
                  key: ValueKey(draft.localId),
                  draft: draft,
                  confirmDelete: () => _confirmDelete(context, l10n),
                  onDismissed: () => context.read<DraftsListBloc>().add(
                    DraftDeleteRequested(draft.localId),
                  ),
                  onTap: () => context.read<DraftsListBloc>().add(
                    DraftResumeRequested(draft.localId),
                  ),
                  onRemind: () => _requestReminder(context, draft),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// `DraftsListLoading`'s placeholder — Drift's `.watch()` emits its first
/// snapshot almost immediately (see `DraftsListLoading`'s own doc comment),
/// so this is expected to be very short-lived in practice, but still real
/// enough to be worth a skeleton shaped like `_DraftCard` rather than a
/// bare spinner, per this branch's task ("skeleton loaders for async
/// screens"). A fixed 3 placeholder rows — not driven by any real count,
/// since the actual number of drafts isn't known yet at this point.
class _DraftsListSkeleton extends StatelessWidget {
  const _DraftsListSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, _) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonBox(),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(width: 96, height: 12),
          ],
        ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.confirmDelete,
    required this.onDismissed,
    required this.onTap,
    required this.onRemind,
    super.key,
  });

  final Draft draft;
  final Future<bool> Function() confirmDelete;
  final VoidCallback onDismissed;
  final VoidCallback onTap;

  /// PRD §6.12/§8.5's Local Post Reminder entry point — see
  /// `_DraftsViewState._requestReminder`.
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    return Dismissible(
      key: ValueKey('dismissible_${draft.localId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDelete(),
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.interactiveDestructiveDefault,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Icon(Icons.delete_outline, color: colors.bgSurface),
      ),
      child: InkWell(
        key: Key('draft_card_${draft.localId}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: colors.bgSurface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _snippet(draft.inputText),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _relativeSavedLabel(l10n, draft.lastSavedAt),
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  // Own tappable target, deliberately smaller than
                  // AppSpacing.minTapTarget's 48px floor would suggest —
                  // IconButton already enforces Material's 48px minimum
                  // hit-test area via its built-in padding regardless of
                  // the icon's visual size, so no extra sizing is needed
                  // here.
                  IconButton(
                    key: Key('draft_remind_button_${draft.localId}'),
                    icon: const Icon(Icons.notifications_outlined),
                    color: colors.textSecondary,
                    tooltip: l10n.remindersCardAction,
                    onPressed: onRemind,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
