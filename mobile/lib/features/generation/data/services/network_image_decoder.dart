import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';

/// Fetches the bytes behind a `GenerateImageResponse.image_url` and decodes
/// them into a [ui.Image], ready to become a `CanvasScene.backgroundImage`
/// (`core/render_engine/canvas_scene.dart`).
///
/// **No prior "load a network URL into a decoded image" plumbing existed
/// in this codebase** (checked: `brand_kit`'s logo flow only ever decodes
/// *local, already-in-memory* picked bytes via
/// `LogoUploadHardener`/`ui.instantiateImageCodec` — never fetches
/// anything over HTTP itself). This is the first. No new dependency was
/// added for it: `dio` is already a pinned dependency and `dart:ui`'s
/// codec API is already used elsewhere in this codebase for decode
/// (`LogoUploadHardener`) — this class just combines the two.
///
/// **Deliberately constructs its own bare [Dio] instead of depending on
/// the app's shared, DI-injected `Dio`** (`core/network/dio_client.dart`).
/// The shared instance carries `AuthInterceptor`, which attaches this
/// app's bearer access token to *every* outgoing request unconditionally
/// (see that class's `onRequest`). `image_url` is a plain asset URL, not
/// one of this app's own API endpoints — against a real backend it's
/// likely a signed CDN link that doesn't need (and shouldn't receive) an
/// `Authorization` header; in mock mode
/// (`FakeGenerationRemoteDataSource`) it's a third-party placeholder host
/// (`picsum.photos`) that must never see this user's token at all. Reusing
/// the shared client would leak a live bearer token to an arbitrary
/// image host — flagged here as a deliberate security decision, not an
/// oversight, per mobile/.claude/skills/flutter-security/SKILL.md.
@injectable
class NetworkImageDecoder {
  final Dio _plainDio = Dio();

  Future<Result<Failure, ui.Image>> decode(String url) async {
    Uint8List bytes;
    try {
      final response = await _plainDio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) {
        return const Result.err(
          UnexpectedFailure("Couldn't load the generated image."),
        );
      }
      bytes = Uint8List.fromList(data);
    }
    // Network fetch failures here are surfaced as a plain UnexpectedFailure
    // rather than routed through ApiExceptionMapper's typed ApiErrorType
    // taxonomy — that taxonomy models `/generate/*`/other first-party API
    // responses (quota, moderation, validation, ...), none of which apply
    // to "fetching a plain asset URL failed." A generic message is
    // accurate here, not a missed classification.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        UnexpectedFailure("Couldn't load the generated image."),
      );
    }

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return Result.ok(frame.image);
    }
    // The platform image codec can throw a variety of undocumented
    // exception types for a malformed/unsupported response body — same
    // reasoning as LogoUploadHardener's equivalent catch-all.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        UnexpectedFailure("Couldn't read the generated image."),
      );
    }
  }
}
