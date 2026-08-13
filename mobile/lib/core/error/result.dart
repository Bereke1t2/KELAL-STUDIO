/// Sealed Result type used across the domain/data boundary instead of throwing.
///
/// Every repository method and use case returns `Result<Failure, T>` rather
/// than a raw value or a thrown exception. This is a deliberate, minimal
/// alternative to `fpdart`/`dartz`: Dart 3 sealed classes give exhaustive
/// `switch` handling for free, without adding a functional-programming
/// dependency the rest of the codebase doesn't otherwise need.
///
/// See mobile/.claude/skills/flutter-architecture/SKILL.md for the layering
/// rule this exists to support (domain/data never throw across a public API).
sealed class Result<F extends Failure, S> {
  const Result();

  const factory Result.ok(S value) = Ok<F, S>;
  const factory Result.err(F failure) = Err<F, S>;

  bool get isOk => this is Ok<F, S>;
  bool get isErr => this is Err<F, S>;

  /// Exhaustive pattern-matching helper. Prefer this (or a `switch`
  /// expression directly on the sealed type) over `isOk`/`isErr` checks
  /// followed by unsafe casts.
  T when<T>({
    required T Function(S value) ok,
    required T Function(F failure) err,
  }) {
    return switch (this) {
      Ok<F, S>(:final value) => ok(value),
      Err<F, S>(:final failure) => err(failure),
    };
  }

  /// Returns the success value or `null`. Useful in widget/presentation code
  /// where you've already branched on `isOk`/`isErr` via a BlocBuilder state.
  S? get valueOrNull => switch (this) {
    Ok<F, S>(:final value) => value,
    Err<F, S>() => null,
  };
}

final class Ok<F extends Failure, S> extends Result<F, S> {
  const Ok(this.value);
  final S value;
}

final class Err<F extends Failure, S> extends Result<F, S> {
  const Err(this.failure);
  final F failure;
}

/// Base type for all domain-level failures. Concrete failures are sealed
/// per-feature (e.g. `AuthFailure`) so `switch` statements over them are
/// exhaustive at the call site. `message` must always be plain-language and
/// safe to show a user — never a raw exception string or stack trace (see
/// the flutter-security skill's "no raw errors surfaced to UI" rule).
abstract class Failure {
  const Failure(this.message);
  final String message;
}

/// The typed error taxonomy from the PRD's `/generate/*` endpoints
/// (PRD §11): the mobile client must branch UI messaging on this typed
/// field, never on HTTP status alone. Every remote data source maps
/// transport/parsing errors into one of these before they reach a repository.
enum ApiErrorType {
  quotaExceeded,
  providerTimeout,
  moderationRefused,
  malformedOutput,
  validationError,
  network,
  unauthorized,
  unknown,
}

class ApiFailure extends Failure {
  const ApiFailure({
    required this.type,
    required String message,
    this.resetsAt,
    this.moderationReason,
  }) : super(message);

  final ApiErrorType type;

  /// Present only when [type] is [ApiErrorType.quotaExceeded] — when the
  /// user's quota resets, per PRD §6.14 (quota state must be explainable,
  /// not just a bare refusal).
  final DateTime? resetsAt;

  /// Present only when [type] is [ApiErrorType.moderationRefused]. Per PRD
  /// §6.4 this must already be a plain-language, localized-to-input-language
  /// string from the backend — never a raw classifier code.
  final String? moderationReason;
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
