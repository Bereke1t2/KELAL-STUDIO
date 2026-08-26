import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:kelal_studio/core/theme/app_colors.dart';
import 'package:kelal_studio/core/theme/app_spacing.dart';
import 'package:kelal_studio/core/theme/app_typography.dart';
import 'package:kelal_studio/features/settings/presentation/bloc/account_bloc.dart';
import 'package:kelal_studio/features/settings/presentation/bloc/account_event.dart';
import 'package:kelal_studio/features/settings/presentation/bloc/account_state.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

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
                'Account',
                style: AppTypography.display.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Email',
                    style: AppTypography.body.copyWith(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'you@business.com',
                    style: AppTypography.body.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxxl),
              Text(
                'SECURITY',
                style: AppTypography.caption.copyWith(
                  color: context.colors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Change Password',
                style: AppTypography.body.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Divider(color: context.colors.borderSubtle, height: 1),
              const SizedBox(height: AppSpacing.lg),
              GestureDetector(
                onTap: () =>
                    context.push('/settings/account_delete_consequence'),
                child: Text(
                  'Delete Account',
                  style: AppTypography.body.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
