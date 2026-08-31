import 'package:kelal_studio/core/error/result.dart';

/// The typed failure taxonomy for PRD §6.11's export/share surface —
/// deliberately its own type, not a reuse of [ApiErrorType]: every failure
/// mode here is local-device (gallery permission/write, the OS Share
/// Sheet), never a `/generate/*` server response, so folding it into the
/// API error taxonomy would misrepresent a local failure as a backend one
/// (same reasoning `LogoValidationFailure`'s doc comment gives for staying
/// separate from `ApiFailure`).
enum ExportFailureType {
  /// `gal` denied gallery-write access — either `Gal.requestAccess()`
  /// returned `false`, or a `GalException` of type `accessDenied` was
  /// thrown by the write call itself (permission revoked between the
  /// pre-check and the write, e.g. via OS settings mid-flow).
  galleryPermissionDenied,

  /// The gallery write itself failed after permission was granted — `gal`'s
  /// `notEnoughSpace`/`notSupportedFormat` `GalException` types both map
  /// here; PRD's review checklist explicitly calls out "device-storage-full"
  /// as a required edge case for this feature.
  galleryWriteFailed,

  /// `share_plus`'s `SharePlus.instance.share` threw. Note there is no
  /// separate "target app not installed" failure mode to model here — the
  /// OS Share Sheet simply omits apps that aren't installed; `share_plus`
  /// raises no error for that case (see `ExportRepositoryImpl.shareImage`'s
  /// doc comment).
  shareFailed,

  /// Anything else unexpected (a non-`GalException` throw, a malformed
  /// `ShareParams`, etc.) — collapsed to a generic plain-language message
  /// rather than surfacing a raw exception string, per
  /// mobile/.claude/skills/flutter-security/SKILL.md.
  unknown,
}

/// See [ExportFailureType] for what each case means. [Failure.message] here
/// is a short internal/debug string, not what's shown to the user for any
/// of these typed cases — same convention `ApiFailure` establishes:
/// presentation switches on [type] and picks its own `AppLocalizations`
/// string (see `ExportPage`'s error mapping), it does not render [message]
/// directly.
class ExportFailure extends Failure {
  const ExportFailure({required this.type, required String message})
    : super(message);

  final ExportFailureType type;
}
