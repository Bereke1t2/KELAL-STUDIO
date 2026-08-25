import 'package:flutter/material.dart';

import 'package:kelal_studio/core/theme/app_theme.dart';

/// Shows a plain-language error message in a themed [SnackBar]. Extracted
/// 1:1 from the inline `SnackBar` `LoginPage` hand-rolled before this
/// helper existed — same [AppColors.errorBg] background and
/// [AppTypography.bodySmall]/[AppColors.errorText] message style, so
/// existing widget-test assertions on the visible error text keep
/// passing unchanged.
void showErrorSnackBar(BuildContext context, String message) {
  final colors = context.colors;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: colors.errorBg,
      content: Text(
        message,
        style: AppTypography.bodySmall.copyWith(color: colors.errorText),
      ),
    ),
  );
}
