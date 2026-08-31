import 'package:flutter/material.dart';

import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';

/// The Compose route's `AppBar` — still a real `AppBar` (not a hand-rolled
/// header) so `AppRouter`'s own navigation tests keep working unmodified
/// (`find.widgetWithText(AppBar, 'Compose')`), just styled and extended:
/// a two-line title (name + one-line tagline, via `bottom:`) over a soft
/// warm wash fading from `bgBrandSubtle` into the app bar's own surface
/// color, instead of a flat single-line bar. Extracted out of
/// `app_router.dart`'s route table (kept intentionally thin — see its own
/// doc comment) the same way `QuotaStatusBadge`/`EmailVerificationGate`
/// already are their own widgets rather than inline route-builder code.
class ComposeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ComposeAppBar({super.key});

  // kToolbarHeight (the AppBar's own default) covers the title row;
  // `bottom` adds a second, independently-sized band for the tagline —
  // AppBar computes its total height as the sum of both automatically, so
  // this doesn't need its own `preferredSize` math beyond forwarding
  // `bottom`'s.
  static const _bottomHeight = AppSpacing.xxxl;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + _bottomHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    return AppBar(
      title: Text(l10n.navComposeLabel),
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.bgBrandSubtle, colors.bgSurface],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(_bottomHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(
            l10n.composerTagline,
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
