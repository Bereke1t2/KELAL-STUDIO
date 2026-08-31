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
/// **Flagged gap, not silently built**: this only shows a banner — it
/// doesn't itself deep-link into the real resend/verify flow
/// (`CheckYourEmailPage`, `/verify-email`) that `feat/email-verification-flow`
/// later built, since wiring that up needs the signed-in user's email
/// somewhere `AuthSession`/`SecureTokenStorage` doesn't carry today. Real
/// follow-up work for a future branch, out of scope for "just the state
/// plumbing + gate UI" here.
class EmailVerificationGate extends StatefulWidget {
  const EmailVerificationGate({required this.child, super.key});

  final Widget child;

  @override
  State<EmailVerificationGate> createState() => _EmailVerificationGateState();
}

class _EmailVerificationGateState extends State<EmailVerificationGate> {
  // Session-local only, deliberately not a HydratedCubit like
  // ExportOverlaySeenCubit/DraftsDisclosureSeenCubit's "seen once, never
  // again" dismissals — this banner represents a still-true fact (the
  // account isn't verified yet), so it's meant to reappear on the next
  // app launch rather than being silenced forever by one dismiss tap. This
  // only lets the user get it out of the way of *this* screen visit,
  // matching the "static banner, scroll doesn't affect it" fix rather
  // than becoming a permanent opt-out.
  bool _dismissed = false;

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
        if (isVerified || _dismissed) return widget.child;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: ErrorBanner(
                key: const Key('email_verification_gate_banner'),
                title: l10n.emailVerificationGateTitle,
                message: l10n.emailVerificationGateMessage,
                onDismiss: () => setState(() => _dismissed = true),
                dismissSemanticLabel: l10n.emailVerificationGateDismissLabel,
              ),
            ),
            Expanded(child: widget.child),
          ],
        );
      },
    );
  }
}
