import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/auth/domain/entities/auth_session.dart';
import 'package:kelal_studio/features/auth/domain/entities/registration_outcome.dart';

/// Interface only — no `dio`, no `retrofit` import here. The concrete
/// implementation (`data/repositories/auth_repository_impl.dart`) picks a
/// real or fake data source at construction time; nothing above this
/// interface knows or cares which. See
/// mobile/.claude/skills/flutter-networking-data/SKILL.md.
abstract class AuthRepository {
  Future<Result<Failure, AuthSession>> login({
    required String email,
    required String password,
  });

  /// Does NOT establish a session — see [RegistrationOutcome]'s doc
  /// comment. The caller must [verifyEmail] then [login] separately.
  Future<Result<Failure, RegistrationOutcome>> register({
    required String email,
    required String password,
  });

  /// Consumes a purpose-bound verification token (from the account's
  /// verification email). Returns `true` once the account is verified —
  /// idempotent, so a second call for an already-verified account still
  /// returns `true` rather than erroring.
  Future<Result<Failure, bool>> verifyEmail({required String token});

  /// Always succeeds from the caller's point of view unless a genuine
  /// transport/network failure occurs — same anti-enumeration contract as
  /// [requestPasswordReset]: never reveals whether [email] belongs to an
  /// existing or already-verified account.
  Future<Result<Failure, void>> resendVerificationEmail({
    required String email,
  });

  /// Always succeeds from the caller's point of view unless a genuine
  /// transport/network failure occurs — the backend never reveals whether
  /// [email] belongs to an existing account (PRD §6.1 anti-enumeration),
  /// and this method must never introduce a branch that does either.
  Future<Result<Failure, void>> requestPasswordReset({required String email});

  Future<Result<Failure, void>> confirmPasswordReset({
    required String token,
    required String newPassword,
  });

  /// Deletes the signed-in user's account server-side, then (only on
  /// success) clears local session state and emits the logged-out signal —
  /// see `AuthRepositoryImpl.deleteAccount` for why success is confirmed
  /// before any local state is torn down.
  Future<Result<Failure, void>> deleteAccount();

  Future<void> logout();

  /// Broadcasts the current sign-in state: `true` once a session exists,
  /// `false` once it doesn't. On first listen this emits the state as of
  /// right now (derived from whether a stored access token exists), then
  /// emits again on every subsequent [login]/[logout] (and, in future, any
  /// other event that ends a session, e.g. account deletion).
  ///
  /// Deliberately `Stream<bool>`, not a richer session entity/usecase — a
  /// repository-level stream is the right scope for gating navigation
  /// today (see `AppRouter`'s `redirect:`); nothing downstream needs more
  /// than the boolean yet, so this stays pure Dart and dependency-free.
  Stream<bool> watchIsAuthenticated();

  /// Broadcasts the current email-verification state, seeded (on first
  /// listen) from whatever was persisted at the last successful
  /// [login]/[register], and re-emitted on every subsequent one. Kept as
  /// its own `Stream<bool>` (mirroring [watchIsAuthenticated]'s own
  /// deliberately-minimal shape) rather than folding into a richer
  /// `Stream<AuthSession>` — nothing downstream needs more than the
  /// boolean today (see `EmailVerificationGate`).
  Stream<bool> watchEmailVerified();
}
