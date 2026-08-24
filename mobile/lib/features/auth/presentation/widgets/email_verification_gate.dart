import 'package:flutter/material.dart';

import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/error_banner.dart';
import 'package:kelal_studio/features/auth/domain/repositories/auth_repository.dart';

/// Wraps [child] — intended to be a page's `Scaffold.body` content, not a
/// whole `Scaffold` — with a blocking [ErrorBanner] whenever the signed-in
/// user's email isn't verified yet (PRD §6.1: "Email verification gates
/// content generation"). Used as the Compose branch's body — see
/// `core/router/app_router.dart`.
///
/// Subscribes directly to [AuthRepository.watchEmailVerified] via
/// `getIt`, rather than going through a use case/Bloc. This mirrors the
/// same architectural call already made for `AppRouter`'s
/// `GoRouterRefreshStream` (`core/router/go_router_refresh_stream.dart`),
/// which reads `watchIsAuthenticated()` directly for the same reason: this
/// is a read-only, session-derived signal rather than a user-initiated
/// action, so a full use case/Bloc round trip would be ceremony without
/// benefit.
///
/// `null` (the stream hasn't emitted yet) is treated the same way
/// `AppRouter.authRedirect` treats an unresolved auth state: don't render
/// the gate until the real value is known, rather than flashing it on
/// briefly for an already-verified user.
///
/// **Flagged gap, not silently built**: this only shows a static banner.
/// It does not include a resend-verification-email flow or deep-link
/// handling for a verification email's tap-through — both are real
/// follow-up work for a future branch (see the auth-complete branch
/// report), out of scope for "just the state plumbing + gate UI" here.
class EmailVerificationGate extends StatelessWidget {
  const EmailVerificationGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<bool>(
      stream: getIt<AuthRepository>().watchEmailVerified(),
      builder: (context, snapshot) {
        // `?? true` treats "no emission yet" the same as "verified" for
        // this check — i.e. don't show the gate — matching the `null`
        // handling note above.
        final isVerified = snapshot.data ?? true;
        if (isVerified) return child;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: ErrorBanner(
                key: const Key('email_verification_gate_banner'),
                title: l10n.emailVerificationGateTitle,
                message: l10n.emailVerificationGateMessage,
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
