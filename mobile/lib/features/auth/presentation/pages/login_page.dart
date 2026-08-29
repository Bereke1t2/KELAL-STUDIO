import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/l10n/locale_cubit.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/theme/theme_cubit.dart';
import 'package:kelal_studio/core/widgets/error_snack_bar.dart';
import 'package:kelal_studio/core/widgets/primary_button.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/login_bloc.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/login_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/login_state.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<LoginBloc>(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
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
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: const [_LocaleToggleButton(), _ThemeToggleButton()],
      ),
      body: SafeArea(
        child: BlocConsumer<LoginBloc, LoginState>(
          listener: (context, state) {
            if (state is LoginFailure) {
              final message = state.errorType == ApiErrorType.validationError
                  ? l10n.invalidCredentials
                  : state.message;
              showErrorSnackBar(context, message);
            }
          },
          builder: (context, state) {
            final isSubmitting = state is LoginSubmitting;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xxxxl),
                  Text(
                    l10n.appTitle,
                    style: AppTypography.display.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.appTagline,
                    style: AppTypography.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxxxl),
                  TextField(
                    key: const Key('login_email_field'),
                    controller: _emailController,
                    enabled: !isSubmitting,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: l10n.emailLabel),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: const Key('login_password_field'),
                    controller: _passwordController,
                    enabled: !isSubmitting,
                    obscureText: true,
                    decoration: InputDecoration(labelText: l10n.passwordLabel),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  PrimaryButton(
                    key: const Key('login_submit_button'),
                    label: l10n.signIn,
                    isLoading: isSubmitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    child: TextButton(
                      key: const Key('forgot_password_link'),
                      onPressed: () => context.push('/reset-password'),
                      child: Text(l10n.forgotPasswordLink),
                    ),
                  ),
                  Align(
                    child: TextButton(
                      key: const Key('create_account_link'),
                      onPressed: () => context.push('/register'),
                      child: Text(
                        '${l10n.dontHaveAccountPrompt} ${l10n.createAccount}',
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
    context.read<LoginBloc>().add(
      LoginSubmitted(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }
}

/// Explicit dark/light toggle, per mobile/CLAUDE.md — [ThemeCubit] is the
/// single source of truth; this widget only reads/dispatches, never holds
/// its own notion of the current theme.
class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeCubit>().state;
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    return IconButton(
      key: const Key('theme_toggle_button'),
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
      onPressed: () => context.read<ThemeCubit>().toggle(
        MediaQuery.platformBrightnessOf(context),
      ),
    );
  }
}

/// Explicit EN/AM toggle, backed by [LocaleCubit]. Cycles null (follow
/// system) -> en -> am -> en ... so a user can always get back to the
/// device default.
class _LocaleToggleButton extends StatelessWidget {
  const _LocaleToggleButton();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleCubit>().state;
    final label = locale?.languageCode.toUpperCase() ?? 'AUTO';
    return TextButton(
      key: const Key('locale_toggle_button'),
      onPressed: () {
        final next = switch (locale?.languageCode) {
          null => const Locale('en'),
          'en' => const Locale('am'),
          _ => null,
        };
        context.read<LocaleCubit>().setLocale(next);
      },
      child: Text(label),
    );
  }
}
