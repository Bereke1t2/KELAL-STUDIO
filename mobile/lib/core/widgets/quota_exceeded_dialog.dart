import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/widgets/app_bottom_sheet.dart';

/// **Ready-to-use helper, not called from anywhere yet — this is
/// deliberate, not dead code.** `ApiErrorType.quotaExceeded` (see
/// `core/error/result.dart`) is only ever produced today by
/// `ApiExceptionMapper` reacting to a `quota_exceeded` error from
/// `/generate/*`, and no generation call exists in this codebase yet (it's
/// `feat/idea-composer-generation`, a later branch in the stack — see
/// mobile/CLAUDE.md). This helper is wired now so that branch's
/// `/generate/*` error handler has a ready blocking-dialog UI to call the
/// moment it receives a `quotaExceeded` `ApiFailure`, instead of having to
/// build one from scratch.
///
/// Lives in `core/widgets` (not `features/quota/presentation/`) because
/// its only feature-specific dependency, [ApiFailure], is itself a
/// `core/error` type, not a `features/quota` one — so putting it here
/// avoids a future `features/generation` -> `features/quota` dependency
/// just to show a dialog. Reuses [AppDialog]/[showAppDialog] rather than
/// hand-rolling a new modal shell — see mobile/CLAUDE.md.
Future<void> showQuotaExceededDialog(BuildContext context, ApiFailure failure) {
  assert(
    failure.type == ApiErrorType.quotaExceeded,
    'showQuotaExceededDialog expects an ApiFailure of type quotaExceeded',
  );

  final l10n = AppLocalizations.of(context);
  final resetsAt = failure.resetsAt;
  final body = resetsAt != null
      ? l10n.quotaExceededDialogBodyWithReset(
          DateFormat.jm().format(resetsAt.toLocal()),
        )
      : l10n.quotaExceededDialogBodyUnknownReset;

  return showAppDialog(
    context,
    dialog: AppDialog(
      icon: Icons.hourglass_bottom,
      heading: l10n.quotaExceededDialogTitle,
      body: body,
      actionLabel: l10n.quotaExceededDialogAction,
      onActionPressed: () => Navigator.of(context).pop(),
    ),
  );
}
