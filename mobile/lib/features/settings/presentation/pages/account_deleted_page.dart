import 'package:flutter/material.dart';
import 'package:kelal_studio/core/theme/app_colors.dart';
import 'package:kelal_studio/core/theme/app_spacing.dart';
import 'package:kelal_studio/core/theme/app_typography.dart';

class AccountDeletedPage extends StatelessWidget {
  const AccountDeletedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.colors.bgDisabled.withValues(
                    alpha: 0.3,
                  ), // Make it very light like the mockup
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Your account has been deleted',
                style: AppTypography.title.copyWith(
                  color: context.colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  'Everything on this device tied to Kelal Studio '
                  'has been removed. Thank you for trying it.',
                  style: AppTypography.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
