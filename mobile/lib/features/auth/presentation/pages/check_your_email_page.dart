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
import 'package:kelal_studio/features/auth/presentation/bloc/resend_verification_bloc.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/resend_verification_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/resend_verification_state.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/verify_email_confirm_bloc.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/verify_email_confirm_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/verify_email_confirm_state.dart';

/// Reached right after `RegisterPage` submits successfully (PRD §11,
/// register-verification) — registration no longer signs the user in, it
/// only creates the account and dispatches a verification email; this
/// screen is that "we sent you a link" confirmation, a resend action, and
/// — same reasoning/pattern as `ResetPasswordConfirmPage`'s manual
/// token-entry field — a manual **paste the code** field, since deep-link
/// handling for an actual tap-through from the email is out of scope here
/// (Android App Links/iOS Universal Links need domain verification files
/// this repo has no real domain to serve yet; see
/// `VerifyEmailUseCase`'s doc comment for the same note from the domain
/// side). This mirrors the exact same flagged gap/workaround
/// `ResetPasswordConfirmPage` already established for the password-reset
/// flow, rather than inventing a different pattern for this one.
class CheckYourEmailPage extends StatelessWidget {
  const CheckYourEmailPage({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<ResendVerificationBloc>()),
        BlocProvider(create: (_) => getIt<VerifyEmailConfirmBloc>()),
      ],
      child: _CheckYourEmailView(email: email),
    );
  }
}

class _CheckYourEmailView extends StatefulWidget {
  const _CheckYourEmailView({required this.email});

  final String email;

  @override
  State<_CheckYourEmailView> createState() => _CheckYourEmailViewState();
}

class _CheckYourEmailViewState extends State<_CheckYourEmailView> {
  final _tokenController = TextEditingController();

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkYourEmailTitle)),
      body: SafeArea(
        child: MultiBlocListener(
          listeners: [
            BlocListener<ResendVerificationBloc, ResendVerificationState>(
              listener: (context, state) {
                if (state is ResendVerificationFailure) {
                  showErrorSnackBar(context, state.message);
                }
                if (state is ResendVerificationSent) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: colors.successBg,
                      content: Text(
                        l10n.checkYourEmailResendSuccessMessage,
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.successText,
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
            BlocListener<VerifyEmailConfirmBloc, VerifyEmailConfirmState>(
              listener: (context, state) {
                if (state is VerifyEmailConfirmFailure) {
                  showErrorSnackBar(context, state.message);
                }
              },
            ),
          ],
          child: BlocBuilder<VerifyEmailConfirmBloc, VerifyEmailConfirmState>(
            builder: (context, verifyState) {
              if (verifyState is VerifyEmailConfirmSuccess) {
                return _VerifiedView(l10n: l10n, colors: colors);
              }
              final isVerifying = verifyState is VerifyEmailConfirmSubmitting;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    Icon(
                      Icons.mark_email_unread_outlined,
                      size: 48,
                      color: colors.primaryDefault,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.checkYourEmailHeading,
                      textAlign: TextAlign.center,
                      style: AppTypography.title.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.checkYourEmailBody(widget.email),
                      key: const Key('check_your_email_body'),
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    BlocBuilder<
                      ResendVerificationBloc,
                      ResendVerificationState
                    >(
                      builder: (context, resendState) {
                        final isSending =
                            resendState is ResendVerificationSending;
                        return TextButton(
                          key: const Key('check_your_email_resend_button'),
                          onPressed: isSending
                              ? null
                              : () =>
                                    context.read<ResendVerificationBloc>().add(
                                      ResendVerificationRequested(
                                        email: widget.email,
                                      ),
                                    ),
                          child: Text(l10n.checkYourEmailResendButton),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      key: const Key('check_your_email_token_field'),
                      controller: _tokenController,
                      enabled: !isVerifying,
                      label: l10n.checkYourEmailTokenLabel,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      key: const Key('check_your_email_verify_button'),
                      label: l10n.checkYourEmailVerifyButton,
                      isLoading: isVerifying,
                      onPressed: () {
                        context.read<VerifyEmailConfirmBloc>().add(
                          VerifyEmailConfirmSubmitted(
                            token: _tokenController.text.trim(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: TextButton(
                        key: const Key('check_your_email_back_to_sign_in'),
                        onPressed: () => context.go(AppRouter.loginLocation),
                        child: Text(l10n.backToSignIn),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VerifiedView extends StatelessWidget {
  const _VerifiedView({required this.l10n, required this.colors});

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
            l10n.checkYourEmailVerifiedMessage,
            key: const Key('check_your_email_verified_message'),
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(
            key: const Key('check_your_email_verified_sign_in'),
            label: l10n.backToSignIn,
            onPressed: () => context.go(AppRouter.loginLocation),
          ),
        ],
      ),
    );
  }
}
