import 'package:kelal_studio/core/error/result.dart';

/// A client-side, pre-upload rejection from the "defense-in-depth" logo
/// hardening check (see `data/services/logo_upload_hardener.dart`) —
/// distinct from [ApiFailure] because the server was never contacted: the
/// picked file was rejected locally (too large, unreadable, or otherwise
/// unfit to re-encode) before any network call happened.
///
/// PRD §6.8: the server re-validates independently. Nothing in this app may
/// treat a *successful* upload (i.e. the absence of this failure) as proof
/// the file is "safe" — it only means the client-side courtesy check didn't
/// reject it. See the doc comment on `LogoUploadHardener` for the exact,
/// limited scope of what this check actually does.
class LogoValidationFailure extends Failure {
  const LogoValidationFailure(super.message);
}
