import 'package:flutter/material.dart';

import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';

/// Bare-bones placeholder for a bottom-nav branch whose real feature UI
/// hasn't been built yet — Drafts/Brand/Settings, and Compose until the
/// Idea Composer branch lands. Deliberately plain (no design-system
/// component beyond the shared [AppTypography]/`context.colors` tokens),
/// so no golden test is warranted here — see mobile/CLAUDE.md's
/// golden-testing section for what actually needs one.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({required this.title, super.key});

  /// AppBar title — one of the `nav*Label` ARB strings, shared with the
  /// bottom nav tab's own label.
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          AppLocalizations.of(context).comingSoonMessage,
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}
