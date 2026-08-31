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
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_request_bloc.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_request_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_request_state.dart';

class ResetPasswordRequestPage extends StatelessWidget {
  const ResetPasswordRequestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ResetPasswordRequestBloc>(),
      child: const _ResetPasswordRequestView(),
    );
  }
}

class _ResetPasswordRequestView extends StatefulWidget {
  const _ResetPasswordRequestView();

  @override
  State<_ResetPasswordRequestView> createState() =>
      _ResetPasswordRequestViewState();
}

class _ResetPasswordRequestViewState extends State<_ResetPasswordRequestView> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.resetPasswordRequestTitle)),
      body: SafeArea(
        child:
            BlocConsumer<ResetPasswordRequestBloc, ResetPasswordRequestState>(
              listener: (context, state) {
                if (state is ResetPasswordRequestFailure) {
                  showErrorSnackBar(context, state.message);
                }
              },
              builder: (context, state) {
                if (state is ResetPasswordRequestSuccess) {
                  return _SuccessView(l10n: l10n, colors: colors);
                }
                final isSubmitting = state is ResetPasswordRequestSubmitting;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.resetPasswordRequestInstructions,
                        style: AppTypography.body.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      AppTextField(
                        key: const Key('reset_password_request_email_field'),
                        controller: _emailController,
                        enabled: !isSubmitting,
                        keyboardType: TextInputType.emailAddress,
                        label: l10n.emailLabel,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      PrimaryButton(
                        key: const Key('reset_password_request_submit_button'),
                        label: l10n.resetPasswordRequestButton,
                        isLoading: isSubmitting,
                        onPressed: () {
                          context.read<ResetPasswordRequestBloc>().add(
                            ResetPasswordRequestSubmitted(
                              email: _emailController.text.trim(),
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

/// Shown on [ResetPasswordRequestSuccess] — identically whether or not the
/// submitted email belonged to a real account (PRD §6.1 anti-enumeration).
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
            Icons.mark_email_read_outlined,
            size: 48,
            color: colors.primaryDefault,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.resetPasswordRequestSuccessTitle,
            textAlign: TextAlign.center,
            style: AppTypography.title.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.resetPasswordRequestSuccessMessage,
            key: const Key('reset_password_request_success_message'),
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          TextButton(
            key: const Key('reset_password_request_back_to_sign_in'),
            onPressed: () => context.go(AppRouter.loginLocation),
            child: Text(l10n.backToSignIn),
          ),
        ],
      ),
    );
  }
}
