import 'package:flutter/material.dart';

import 'package:kelal_studio/core/theme/app_colors.dart';
import 'package:kelal_studio/core/theme/app_spacing.dart';
import 'package:kelal_studio/core/theme/app_typography.dart';

// Re-export so feature code only needs `import 'core/theme/app_theme.dart'`.
export 'app_colors.dart';
export 'app_spacing.dart';
export 'app_typography.dart';

/// Assembles Material 3 [ThemeData] from the Figma-sourced tokens in
/// [AppColors]/[AppTypography]/[AppSpacing]. Widgets should prefer the
/// semantic tokens directly (`context.colors.textPrimary`,
/// `AppTypography.body`) over reading `Theme.of(context).colorScheme` —
/// the ColorScheme mapping below exists only so stock Material widgets
/// (which read ColorScheme internally) render on-brand automatically.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.primaryDefault,
      onPrimary: colors.bgSurface,
      secondary: colors.borderBrand,
      onSecondary: colors.bgSurface,
      error: colors.errorBorder,
      onError: colors.bgSurface,
      surface: colors.bgSurface,
      onSurface: colors.textPrimary,
      surfaceContainerHighest: colors.bgSurfaceRaised,
      outline: colors.borderDefault,
      outlineVariant: colors.borderSubtle,
      inverseSurface: colors.bgInverse,
      onInverseSurface: colors.bgSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.bgCanvas,
      fontFamily: AppTypography.fontFamily,
      textTheme: TextTheme(
        displaySmall: AppTypography.display.copyWith(color: colors.textPrimary),
        titleLarge: AppTypography.title.copyWith(color: colors.textPrimary),
        bodyLarge: AppTypography.body.copyWith(color: colors.textPrimary),
        bodyMedium: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
        labelLarge: AppTypography.label.copyWith(color: colors.textSecondary),
        bodySmall: AppTypography.caption.copyWith(color: colors.textTertiary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bgSurface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primaryDefault,
          foregroundColor: colors.bgSurface,
          disabledBackgroundColor: colors.primaryDisabledBg,
          minimumSize: const Size.fromHeight(AppSpacing.minTapTarget),
          textStyle: AppTypography.buttonLabel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.bgSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colors.borderFocus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colors.borderError),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.bgSurfaceRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colors.borderSubtle),
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.borderSubtle, thickness: 1),
    );
  }
}
