import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kelal_studio/core/theme/app_colors.dart';
import 'package:kelal_studio/core/theme/app_spacing.dart';
import 'package:kelal_studio/core/theme/app_typography.dart';

class AccountDeleteConsequencePage extends StatelessWidget {
  const AccountDeleteConsequencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    '← Back',
                    style: AppTypography.bodySmall.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Delete Account',
                style: AppTypography.display.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'This permanently deletes your account and '
                'everything tied to it:',
                style: AppTypography.body.copyWith(
                  color: context.colors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildBulletItem(context, 'All drafts saved on this device'),
              const SizedBox(height: AppSpacing.md),
              _buildBulletItem(
                context,
                'Your Brand Kit, logo, and saved preferences',
              ),
              const SizedBox(height: AppSpacing.md),
              _buildBulletItem(context, 'Your generation and quota history'),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'This cannot be undone.',
                style: AppTypography.body.copyWith(
                  color: context.colors.interactiveDestructiveDefault,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      context.push('/settings/account_delete_confirm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        context.colors.interactiveDestructiveDefault,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: AppTypography.buttonLabel.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulletItem(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '—  ',
          style: AppTypography.body.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: AppTypography.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
