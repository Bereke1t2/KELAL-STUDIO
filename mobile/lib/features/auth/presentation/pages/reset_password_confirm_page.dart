import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/router/app_router.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/app_text_field.dart';
import 'package:kelal_studio/core/widgets/error_snack_bar.dart';
import 'package:kelal_studio/core/widgets/primary_button.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_confirm_bloc.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_confirm_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_confirm_state.dart';

/// Manual token-entry screen — deep-link handling for a tap-through from
/// the actual reset email is out of scope for this branch (see
/// mobile/.claude/skills/flutter-architecture/SKILL.md's "flag, don't
/// silently assume" rule and the auth-complete branch report). The user
/// pastes the code they received via `ResetPasswordRequestPage`'s flow.
class ResetPasswordConfirmPage extends StatelessWidget {
  const ResetPasswordConfirmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ResetPasswordConfirmBloc>(),
      child: const _ResetPasswordConfirmView(),
    );
  }
}

class _ResetPasswordConfirmView extends StatefulWidget {
  const _ResetPasswordConfirmView();

  @override
  State<_ResetPasswordConfirmView> createState() =>
      _ResetPasswordConfirmViewState();
}

class _ResetPasswordConfirmViewState extends State<_ResetPasswordConfirmView> {
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _tokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.resetPasswordConfirmTitle)),
      body: SafeArea(
        child:
            BlocConsumer<ResetPasswordConfirmBloc, ResetPasswordConfirmState>(
              listener: (context, state) {
                if (state is ResetPasswordConfirmFailure) {
                  showErrorSnackBar(context, state.message);
                }
              },
              builder: (context, state) {
                if (state is ResetPasswordConfirmSuccess) {
                  return _SuccessView(l10n: l10n, colors: colors);
                }
                final isSubmitting = state is ResetPasswordConfirmSubmitting;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      AppTextField(
                        key: const Key('reset_password_confirm_token_field'),
                        controller: _tokenController,
                        enabled: !isSubmitting,
                        label: l10n.resetPasswordConfirmTokenLabel,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        key: const Key(
                          'reset_password_confirm_new_password_field',
                        ),
                        controller: _newPasswordController,
                        enabled: !isSubmitting,
                        obscureText: true,
                        label: l10n.newPasswordLabel,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      PrimaryButton(
                        key: const Key('reset_password_confirm_submit_button'),
                        label: l10n.resetPasswordConfirmButton,
                        isLoading: isSubmitting,
                        onPressed: () {
                          context.read<ResetPasswordConfirmBloc>().add(
                            ResetPasswordConfirmSubmitted(
                              token: _tokenController.text.trim(),
                              newPassword: _newPasswordController.text,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.l10n, required this.colors});

  final AppLocalizations l10n;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: colors.primaryDefault,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.resetPasswordConfirmSuccessMessage,
            key: const Key('reset_password_confirm_success_message'),
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(
            key: const Key('reset_password_confirm_back_to_sign_in'),
            label: l10n.backToSignIn,
            onPressed: () => context.go(AppRouter.loginLocation),
          ),
        ],
      ),
    );
  }
}
