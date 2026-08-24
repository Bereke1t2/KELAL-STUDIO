import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/logo_validation_failure.dart';

/// Client-side, pre-upload "courtesy check" for a picked logo image —
/// re-encodes it to PNG (stripping embedded metadata such as EXIF/GPS and
/// normalizing whatever format the picker returned) and downscales it if
/// either dimension exceeds [maxDimensionPx], rejecting outright if the
/// raw pick is unreasonably large or unreadable.
///
/// **This is defense-in-depth only — it does not make the upload "safe."**
/// Per PRD §6.8, the server independently re-validates every uploaded
/// asset; nothing in this app may treat a file that passes this check as
/// pre-cleared. What this specifically does and does not do:
///  - Re-encoding via [ui.instantiateImageCodec] +
///    `Image.toByteData(format: png)` decodes to a raw RGBA buffer and
///    re-encodes fresh — any malformed trailing bytes, embedded scripts, or
///    metadata (EXIF/GPS/ICC profiles/thumbnails) that hitchhike inside the
///    *original* file's container do not survive, since nothing about the
///    original byte stream is preserved.
///  - It does **not** perform any content moderation, virus/malware
///    scanning, or verify the image is actually a logo — those are
///    explicitly out of scope for a client-side check and remain the
///    server's job.
///  - A crafted file that exploits a bug in the platform's own image codec
///    during decode is not defended against by this class — that's a
///    platform-level concern, not something re-encoding downstream of the
///    decode can prevent.
///
/// No new image-processing dependency was added for this — Flutter's
/// built-in `dart:ui` codec API is sufficient for decode/downscale/re-encode
/// without pulling in a heavier package for what's explicitly a courtesy
/// check, not a hardening guarantee.
class LogoUploadHardener {
  const LogoUploadHardener();

  /// Reject outright above this raw pick size — generous enough for a
  /// phone-camera photo, small enough that decoding it isn't itself a
  /// worthwhile DoS vector against a low-end device (PRD's low-end-Android
  /// performance target).
  static const int maxInputBytes = 10 * 1024 * 1024; // 10 MB

  /// Longest edge after downscaling — comfortably larger than the 72x72
  /// display tile (`BrandAvatar`) or any realistic logo-in-content usage,
  /// while keeping the re-encoded PNG small.
  static const int maxDimensionPx = 1024;

  Future<Result<Failure, Uint8List>> harden(Uint8List rawBytes) async {
    if (rawBytes.isEmpty) {
      return const Result.err(
        LogoValidationFailure('That file is empty or unreadable.'),
      );
    }
    if (rawBytes.length > maxInputBytes) {
      return const Result.err(
        LogoValidationFailure(
          'That image is too large (max 10 MB). Please choose a smaller '
          'file.',
        ),
      );
    }

    ui.Image image;
    try {
      final codec = await ui.instantiateImageCodec(rawBytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
    }
    // The platform image codec can throw a variety of undocumented
    // exception types for a malformed/unsupported file — anything thrown
    // here must become a plain-language rejection, not propagate.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        LogoValidationFailure(
          "We couldn't read that image. Please choose a different file.",
        ),
      );
    }

    if (image.width > maxDimensionPx || image.height > maxDimensionPx) {
      final longestEdge = image.width > image.height
          ? image.width
          : image.height;
      final scale = maxDimensionPx / longestEdge;
      final targetWidth = (image.width * scale).round();
      final targetHeight = (image.height * scale).round();
      image.dispose();
      try {
        final resizedCodec = await ui.instantiateImageCodec(
          rawBytes,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        );
        final resizedFrame = await resizedCodec.getNextFrame();
        image = resizedFrame.image;
      }
      // Same reasoning as the first decode's catch-all above.
      // ignore: avoid_catches_without_on_clauses
      catch (_) {
        return const Result.err(
          LogoValidationFailure(
            "We couldn't process that image. Please choose a different "
            'file.',
          ),
        );
      }
    }

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      return const Result.err(
        LogoValidationFailure(
          "We couldn't process that image. Please choose a different file.",
        ),
      );
    }
    return Result.ok(byteData.buffer.asUint8List());
  }
}
