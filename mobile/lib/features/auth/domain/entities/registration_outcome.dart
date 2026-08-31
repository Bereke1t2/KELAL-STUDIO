import 'package:equatable/equatable.dart';

/// The real result of `POST /auth/register` (PRD §11, product-approved
/// 2026-08-25 — see `backend/docs/OPEN_QUESTIONS.md` →
/// `register-verification`): registration does NOT establish a session.
/// The account is created and a verification email is dispatched; the
/// caller must verify (`AuthRepository.verifyEmail`), then log in
/// separately. This replaces the old assumption (baked into the
/// mobile-local mock contract, before a real backend existed) that
/// register returned an `AuthTokens` session directly — see
/// `RegisterBloc`'s doc comment for how the presentation layer adapted.
class RegistrationOutcome extends Equatable {
  const RegistrationOutcome({
    required this.userId,
    required this.verificationSent,
  });

  final String userId;

  /// Whether the verification email was actually dispatched — a transient
  /// delivery failure does NOT fail the registration itself (the account
  /// still exists), so this can be `false` on an otherwise-successful
  /// registration. The UI always offers a resend action regardless of this
  /// value, rather than branching copy on it — the account holder can't
  /// distinguish "never sent" from "sent but not received" anyway.
  final bool verificationSent;

  @override
  List<Object?> get props => [userId, verificationSent];
}
