import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/widgets/app_bottom_sheet.dart';

/// Shown by `ComposerPage` and `GenerationResultPage` when a
/// `/generate/*` call fails with `ApiErrorType.quotaExceeded` (see
/// `core/error/result.dart`).
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
      // Dismissing is all this dialog's action needs to do, and AppDialog
      // handles that itself now (see its onActionPressed doc comment) —
      // this used to also call `Navigator.of(context).pop()` here, using
      // the pre-dialog context, which is the exact bug that comment
      // describes: it crashed the app instead of closing the dialog.
      onActionPressed: () {},
    ),
  );
}
