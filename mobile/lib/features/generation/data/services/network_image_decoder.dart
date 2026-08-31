import 'dart:ui' as ui;

import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/authenticated_asset_client.dart';

/// Fetches the bytes behind a `GenerateImageResponse.image_url` (via
/// [AuthenticatedAssetClient] — see its own doc comment for the
/// same-origin-only auth-attachment story) and decodes them into a
/// [ui.Image], ready to become a `CanvasScene.backgroundImage`
/// (`core/render_engine/canvas_scene.dart`).
@injectable
class NetworkImageDecoder {
  NetworkImageDecoder(this._client);

  final AuthenticatedAssetClient _client;

  Future<Result<Failure, ui.Image>> decode(String url) async {
    final ui.Image image;
    try {
      final bytes = await _client.fetchBytes(url);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
    }
    // Covers both the network fetch (a plain UnexpectedFailure is right
    // here, not ApiExceptionMapper's typed taxonomy — that taxonomy models
    // `/generate/*`/other first-party API responses, none of which apply
    // to "fetching a plain asset URL failed") and the platform image
    // codec, which can throw a variety of undocumented exception types
    // for a malformed/unsupported response body (same reasoning as
    // LogoUploadHardener's equivalent catch-all).
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        UnexpectedFailure("Couldn't load the generated image."),
      );
    }
    return Result.ok(image);
  }
}
