import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/widgets/quota_badge.dart';
import 'package:kelal_studio/features/quota/domain/entities/quota.dart';
import 'package:kelal_studio/features/quota/presentation/bloc/quota_bloc.dart';
import 'package:kelal_studio/features/quota/presentation/bloc/quota_event.dart';
import 'package:kelal_studio/features/quota/presentation/bloc/quota_state.dart';

/// Self-contained "drop it into a page" widget — provides its own
/// `QuotaBloc` and fetches on mount, the same self-sufficiency
/// `EmailVerificationGate` uses (see that widget's doc comment) rather
/// than requiring every call site to wire a `BlocProvider` by hand.
///
/// This is the feature-owned "smart" half of the `QuotaBadge` split: reads
/// `QuotaBloc`/`Quota` (both feature-owned) and `AppLocalizations`, and
/// converts them into the plain strings/booleans `core/widgets/quota_badge.dart`'s
/// deliberately "dumb" `QuotaBadge` accepts — same split `BrandKitPage`'s
/// `_BrandKitForm` (smart) uses to drive `BrandAvatar` (dumb).
class QuotaStatusBadge extends StatelessWidget {
  const QuotaStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<QuotaBloc>()..add(const QuotaRequested()),
      child: const _QuotaStatusBadgeView(),
    );
  }
}

class _QuotaStatusBadgeView extends StatelessWidget {
  const _QuotaStatusBadgeView();

  /// Warns once either resource is exhausted or within 20% of its limit —
  /// a "nice touch, not required" per this branch's task, so a simple,
  /// undocumented-elsewhere threshold is fine rather than a configurable
  /// one.
  bool _isNearOrAtLimit(Quota quota) {
    bool near(int used, int limit) => limit > 0 && used / limit >= 0.8;
    return quota.isTextExhausted ||
        quota.isImageExhausted ||
        near(quota.textCallsUsed, quota.textCallsLimit) ||
        near(quota.imageCallsUsed, quota.imageCallsLimit);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<QuotaBloc, QuotaState>(
      builder: (context, state) {
        return switch (state) {
          QuotaInitial() || QuotaLoadInProgress() => const QuotaBadge(
            status: QuotaBadgeStatus.loading,
          ),
          QuotaLoadFailure(:final message) => QuotaBadge(
            status: QuotaBadgeStatus.error,
            errorMessage: message,
          ),
          QuotaLoaded(:final quota) => QuotaBadge(
            status: QuotaBadgeStatus.loaded,
            textRemainingLabel: l10n.quotaBadgeTextRemaining(
              (quota.textCallsLimit - quota.textCallsUsed).clamp(
                0,
                quota.textCallsLimit,
              ),
              quota.textCallsLimit,
            ),
            textRemainingShortLabel: l10n.quotaBadgeTextRemainingShort(
              (quota.textCallsLimit - quota.textCallsUsed).clamp(
                0,
                quota.textCallsLimit,
              ),
              quota.textCallsLimit,
            ),
            imageRemainingLabel: l10n.quotaBadgeImageRemaining(
              (quota.imageCallsLimit - quota.imageCallsUsed).clamp(
                0,
                quota.imageCallsLimit,
              ),
              quota.imageCallsLimit,
            ),
            imageRemainingShortLabel: l10n.quotaBadgeImageRemainingShort(
              (quota.imageCallsLimit - quota.imageCallsUsed).clamp(
                0,
                quota.imageCallsLimit,
              ),
              quota.imageCallsLimit,
            ),
            resetLabel: l10n.quotaBadgeResetsAt(
              DateFormat.jm().format(quota.resetsAt.toLocal()),
            ),
            isWarning: _isNearOrAtLimit(quota),
          ),
        };
      },
    );
  }
}
