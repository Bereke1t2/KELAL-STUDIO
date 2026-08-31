import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/app_text_field.dart';
import 'package:kelal_studio/core/widgets/error_snack_bar.dart';
import 'package:kelal_studio/core/widgets/primary_button.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/register_bloc.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/register_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/register_state.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<RegisterBloc>(),
      child: const _RegisterView(),
    );
  }
}

class _RegisterView extends StatefulWidget {
  const _RegisterView();

  @override
  State<_RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<_RegisterView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createAccountTitle)),
      body: SafeArea(
        child: BlocConsumer<RegisterBloc, RegisterState>(
          listener: (context, state) {
            if (state is RegisterFailure) {
              showErrorSnackBar(context, state.message);
            }
            // Registration no longer signs the user in (PRD §11,
            // register-verification), so AppRouter's auth-state redirect
            // never fires here the way it used to — this screen must
            // navigate itself. `go` (not `push`) so Check Your Email
            // replaces Register in history; backing out of it should
            // reach Login, not a stale, already-submitted register form.
            if (state is RegisterSuccess) {
              context.go(
                Uri(
                  path: '/verify-email',
                  queryParameters: {'email': state.email},
                ).toString(),
              );
            }
          },
          builder: (context, state) {
            final isSubmitting = state is RegisterSubmitting;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    key: const Key('register_email_field'),
                    controller: _emailController,
                    enabled: !isSubmitting,
                    keyboardType: TextInputType.emailAddress,
                    label: l10n.emailLabel,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    key: const Key('register_password_field'),
                    controller: _passwordController,
                    enabled: !isSubmitting,
                    obscureText: true,
                    label: l10n.passwordLabel,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  PrimaryButton(
                    key: const Key('register_submit_button'),
                    label: l10n.createAccount,
                    isLoading: isSubmitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: TextButton(
                      key: const Key('back_to_sign_in_link'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(
                        '${l10n.alreadyHaveAccountPrompt} ${l10n.signIn}',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _submit() {
    context.read<RegisterBloc>().add(
      RegisterSubmitted(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }
}
