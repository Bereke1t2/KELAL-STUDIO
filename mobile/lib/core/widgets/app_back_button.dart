import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';

/// Back-navigation control for a pushed page that has no real `AppBar` of
/// its own — `AccountPage`, `AccountDeleteConsequencePage`,
/// `AccountDeleteConfirmPage`, `LegalPage`, `LegalDocumentPage`. Replaces
/// each page's own hand-rolled `GestureDetector` wrapping a literal
/// `'← Back'` string, which had two real problems this widget fixes:
///
/// 1. **No button affordance.** A bare `GestureDetector` + `Text` gives no
///    press feedback (no ink splash/highlight) and no indication it's
///    tappable beyond its color — this wraps the same tap target in an
///    [InkWell] instead, matching every other tappable control in the app.
/// 2. **Hardcoded English.** `'← Back'` was a literal, not
///    [AppLocalizations] — an Amharic-locale user saw English here
///    regardless of `LocaleCubit`'s state, on every page that used it. See
///    [AppLocalizations.backButtonLabel].
///
/// Not a full `AppBar` replacement — these pages deliberately render their
/// own title below this control (see e.g. `LegalDocumentPage`) rather than
/// using an `AppBar`'s title slot, a pre-existing layout choice this widget
/// doesn't change.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    // Align left + a small negative Transform (not negative Padding, which
    // RenderPadding asserts non-negative on) so the enlarged ink/tap target
    // doesn't visibly push the icon in from the page's own edge padding —
    // only the ink splash extends into that margin, not the visible icon.
    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.translate(
        offset: const Offset(-AppSpacing.md, 0),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const Key('app_back_button'),
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.minTapTarget,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      l10n.backButtonLabel,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
