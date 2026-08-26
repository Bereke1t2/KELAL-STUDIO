import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelal_studio/core/l10n/locale_cubit.dart';
import 'package:kelal_studio/core/theme/app_colors.dart';
import 'package:kelal_studio/core/theme/app_spacing.dart';
import 'package:kelal_studio/core/theme/app_typography.dart';
import 'package:kelal_studio/core/theme/theme_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppTypography.display.copyWith(
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        children: [
          _buildSectionHeader(context, 'ACCOUNT'),
          _buildListItem(
            context,
            title: 'Account',
            onTap: () => context.push('/settings/account'),
          ),
          _buildListItem(context, title: 'Brand Kit', onTap: () {}),
          _buildListItem(
            context,
            title: 'Notifications & Reminders',
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionHeader(context, 'PREFERENCES'),
          _buildThemeItem(context),
          _buildLanguageItem(context),
          _buildListItem(
            context,
            title: 'Quota & Usage',
            trailingText: '48 left today',
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionHeader(context, 'ABOUT'),
          _buildListItem(
            context,
            title: 'Legal',
            onTap: () => context.push('/settings/legal'),
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildSignOutItem(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          color: context.colors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context, {
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppTypography.body.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText,
                style: AppTypography.bodySmall.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeItem(BuildContext context) {
    final themeMode = context.watch<ThemeCubit>().state;
    String themeText = 'System';
    if (themeMode == ThemeMode.light) themeText = 'Light';
    if (themeMode == ThemeMode.dark) themeText = 'Dark';

    return _buildListItem(
      context,
      title: 'Theme',
      trailingText: themeText,
      onTap: () {
        context.read<ThemeCubit>().toggle(
          MediaQuery.of(context).platformBrightness,
        );
      },
    );
  }

  Widget _buildLanguageItem(BuildContext context) {
    final locale = context.watch<LocaleCubit>().state;
    String langText = 'English';
    if (locale?.languageCode == 'am') {
      langText = 'Amharic';
    }

    return _buildListItem(
      context,
      title: 'Language & Region',
      trailingText: langText,
      onTap: () {
        final newLocale = locale?.languageCode == 'am'
            ? const Locale('en')
            : const Locale('am');
        context.read<LocaleCubit>().setLocale(newLocale);
      },
    );
  }

  Widget _buildSignOutItem(BuildContext context) {
    return InkWell(
      onTap: () {
        // Clear session and navigate to login
        context.go('/login');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          'Sign Out',
          style: AppTypography.body.copyWith(
            color: context.colors.interactiveDestructiveDefault,
          ),
        ),
      ),
    );
  }
}
