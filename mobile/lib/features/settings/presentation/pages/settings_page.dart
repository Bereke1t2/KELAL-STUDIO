import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/l10n/locale_cubit.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/theme/theme_cubit.dart';
import 'package:kelal_studio/core/widgets/soft_card.dart';

/// Account/Preferences/About, grouped into [SoftCard]s of icon-led rows —
/// the same visual language `ComposerPage` uses (warm gradient `AppBar`
/// wash + tagline, soft-shadowed cards), so the app's two "settings-shaped"
/// screens (a form, and a list of toggles) read as the same product rather
/// than a flat, un-styled list of text rows next to everything else.
///
/// Every row's `onTap` here is unchanged behavior from before this pass —
/// Brand Kit and Notifications & Reminders are still real, pre-existing
/// no-ops (not wired to a route/action yet), and Quota & Usage's trailing
/// count is still the same hardcoded placeholder number, not real
/// `QuotaBloc` data (see `settingsQuotaTrailingPlaceholder`'s ARB
/// description) — this pass is a visual/localization redesign, not a
/// feature-completeness pass on Settings' still-open gaps.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _bottomHeight = AppSpacing.xxxl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSettingsLabel),
        // Same "AppBar stays a real AppBar, just extended" approach as
        // ComposeAppBar — see that widget's doc comment for why (keeps any
        // future `find.widgetWithText(AppBar, ...)`-style navigation test
        // working unmodified).
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
              l10n.settingsTagline,
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.xl,
          AppSpacing.xxl,
          AppSpacing.xxxl,
        ),
        children: [
          _SectionLabel(l10n.settingsSectionAccount),
          const SizedBox(height: AppSpacing.sm),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.person_outline,
                  title: l10n.settingsAccountItem,
                  onTap: () => context.push('/settings/account'),
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.palette_outlined,
                  title: l10n.settingsBrandKitItem,
                  onTap: () {},
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.notifications_outlined,
                  title: l10n.settingsNotificationsItem,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel(l10n.settingsSectionPreferences),
          const SizedBox(height: AppSpacing.sm),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const _ThemeRow(),
                const _RowDivider(),
                const _LanguageRow(),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.bolt_outlined,
                  title: l10n.settingsQuotaItem,
                  trailing: l10n.settingsQuotaTrailingPlaceholder(48),
                  showChevron: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel(l10n.settingsSectionAbout),
          const SizedBox(height: AppSpacing.sm),
          SoftCard(
            padding: EdgeInsets.zero,
            child: _SettingsRow(
              icon: Icons.gavel_outlined,
              title: l10n.settingsLegalItem,
              onTap: () => context.push('/settings/legal'),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          SoftCard(
            padding: EdgeInsets.zero,
            child: _SettingsRow(
              icon: Icons.logout,
              title: l10n.settingsSignOutItem,
              iconColor: colors.interactiveDestructiveDefault,
              titleColor: colors.interactiveDestructiveDefault,
              showChevron: false,
              onTap: () => context.go('/login'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small-caps eyebrow above a group of [SoftCard] rows — kept in
/// `settingsSection*`'s existing all-caps English casing (a common,
/// recognizable "Settings app" convention, e.g. iOS's own Settings) rather
/// than switched to `ComposerPage`'s icon-led sentence-case section
/// headers; the two screens are different enough in kind (a short form vs.
/// a list of preferences) that matching treatments exactly isn't actually
/// more consistent, just more uniform.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: context.colors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// One tappable row inside a [SoftCard] — an icon, a title, an optional
/// trailing value, and a chevron unless [showChevron] is false (the three
/// toggle/value rows — Theme, Language, Quota — aren't navigation, tapping
/// them changes a value in place, so a chevron there would promise a
/// destination that doesn't exist).
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.iconColor,
    this.titleColor,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? trailing;
  final Color? iconColor;
  final Color? titleColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? colors.primaryDefault),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: AppTypography.body.copyWith(
                  color: titleColor ?? colors.textPrimary,
                ),
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing!,
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (showChevron)
              Icon(Icons.chevron_right, size: 20, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Divider(height: 1, color: context.colors.borderSubtle),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeMode = context.watch<ThemeCubit>().state;
    final (icon, label) = switch (themeMode) {
      ThemeMode.system => (
        Icons.brightness_auto_outlined,
        l10n.settingsThemeSystem,
      ),
      ThemeMode.light => (Icons.light_mode_outlined, l10n.settingsThemeLight),
      ThemeMode.dark => (Icons.dark_mode_outlined, l10n.settingsThemeDark),
    };
    return _SettingsRow(
      icon: icon,
      title: l10n.settingsThemeItem,
      trailing: label,
      showChevron: false,
      onTap: () => context.read<ThemeCubit>().toggle(
        MediaQuery.of(context).platformBrightness,
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.watch<LocaleCubit>().state;
    final isAmharic = locale?.languageCode == 'am';
    return _SettingsRow(
      icon: Icons.language,
      title: l10n.settingsLanguageItem,
      trailing: isAmharic
          ? l10n.settingsLanguageAmharic
          : l10n.settingsLanguageEnglish,
      showChevron: false,
      onTap: () => context.read<LocaleCubit>().setLocale(
        isAmharic ? const Locale('en') : const Locale('am'),
      ),
    );
  }
}
