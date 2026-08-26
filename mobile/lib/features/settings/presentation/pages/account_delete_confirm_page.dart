import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:kelal_studio/core/theme/app_colors.dart';
import 'package:kelal_studio/core/theme/app_spacing.dart';
import 'package:kelal_studio/core/theme/app_typography.dart';
import 'package:kelal_studio/features/settings/presentation/bloc/account_bloc.dart';
import 'package:kelal_studio/features/settings/presentation/bloc/account_event.dart';
import 'package:kelal_studio/features/settings/presentation/bloc/account_state.dart';

class AccountDeleteConfirmPage extends StatefulWidget {
  const AccountDeleteConfirmPage({super.key});

  @override
  State<AccountDeleteConfirmPage> createState() => _AccountDeleteConfirmPageState();
}

class _AccountDeleteConfirmPageState extends State<AccountDeleteConfirmPage> {
  String? _selectedReason;
  String _typedConfirm = '';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GetIt.I<AccountBloc>(),
      child: BlocListener<AccountBloc, AccountState>(
        listener: (context, state) {
          if (state is AccountDeleted) {
            context.go('/settings/account_deleted');
          } else if (state is AccountDeleteError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: Scaffold(
          backgroundColor: context.colors.bgCanvas,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
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
                          'Why are you leaving? (optional)',
                          style: AppTypography.caption.copyWith(
                            color: context.colors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildReasonCard('Not what I needed'),
                        const SizedBox(height: AppSpacing.sm),
                        _buildReasonCard('Too hard to use'),
                        const SizedBox(height: AppSpacing.sm),
                        _buildReasonCard('Switching to another tool'),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          'Type DELETE to confirm',
                          style: AppTypography.caption.copyWith(
                            color: context.colors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          onChanged: (val) {
                            setState(() {
                              _typedConfirm = val;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'DELETE',
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: context.colors.interactiveDestructiveDefault),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: context.colors.interactiveDestructiveDefault, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: AppSpacing.xxl),
                        BlocBuilder<AccountBloc, AccountState>(
                          builder: (context, state) {
                            final isEnabled = _typedConfirm == 'DELETE' && state is! AccountDeleting;
                            
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isEnabled
                                    ? () => context.read<AccountBloc>().add(const AccountDeleteRequested())
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isEnabled 
                                      ? context.colors.interactiveDestructiveDefault 
                                      : context.colors.bgDisabled,
                                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                                  disabledBackgroundColor: context.colors.bgDisabled,
                                ),
                                child: state is AccountDeleting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'Permanently Delete Account',
                                        style: AppTypography.buttonLabel.copyWith(
                                          color: isEnabled ? Colors.white : context.colors.textSecondary,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReasonCard(String reason) {
    final isSelected = _selectedReason == reason;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedReason = reason;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? context.colors.primaryDefault : context.colors.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          reason,
          style: AppTypography.body.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
