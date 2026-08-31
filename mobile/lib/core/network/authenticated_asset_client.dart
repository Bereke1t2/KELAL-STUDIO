import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/env/env.dart';
import 'package:kelal_studio/core/storage/secure_token_storage.dart';

/// The one place a bare, `AuthInterceptor`-free [Dio] instance is
/// constructed — see [AuthenticatedAssetClient]'s doc comment for why this
/// must never be the app's shared, DI-default `Dio`
/// (`core/network/dio_client.dart`'s `NetworkModule`). `@Named` rather than
/// a second unnamed `Dio` registration, since get_it/injectable can't
/// otherwise disambiguate two providers of the same type.
@module
abstract class AssetClientModule {
  @Named('unauthenticatedDio')
  @lazySingleton
  Dio unauthenticatedDio() => Dio();
}

/// Fetches raw bytes for a first-party asset URL — `GET /assets/{id}`'s
/// response, whether reached via a `GenerateImageResponse.image_url` or a
/// self-assembled `/v1/assets/{brandKit.logoAssetId}` path (there's no
/// `BrandKit` field carrying a ready-made URL, only the bare id).
///
/// **Deliberately injected with its own [Dio] instance
/// (`@Named('unauthenticatedDio')`, see `AssetClientModule` below) instead
/// of the app's shared, DI-injected default `Dio`**
/// (`core/network/dio_client.dart`). The shared instance's
/// `AuthInterceptor` attaches this app's bearer token to *every* outgoing
/// request unconditionally — reusing it here would leak a live token to
/// whatever host a URL happened to point at, including a third-party CDN.
/// That stance is preserved deliberately: [fetchBytes] only ever attaches
/// the token when its `url` argument is relative or absolute-path (i.e. has no
/// `scheme://host` of its own) — which can only mean "this app's own
/// API," never a third party.
///
/// **Why a token is needed at all**: the real backend's `GET /assets/{id}`
/// is bearer-authenticated and owner-checked (see
/// `backend/api/openapi.yaml`'s `getAsset`) — a plain unauthenticated fetch
/// 401s. `image_url` was originally assumed to be an absolute,
/// unauthenticated signed link; against the real backend it's actually a
/// relative, gated path, which is what this class exists to handle
/// correctly.
@injectable
class AuthenticatedAssetClient {
  AuthenticatedAssetClient(
    @Named('unauthenticatedDio') this._plainDio,
    this._tokenStorage,
  );

  final Dio _plainDio;
  final SecureTokenStorage _tokenStorage;

  Future<Options> _optionsFor(String url) async {
    if (Uri.parse(url).hasScheme) return Options();
    final accessToken = await _tokenStorage.readAccessToken();
    return Options(
      headers: accessToken != null
          ? {'Authorization': 'Bearer $accessToken'}
          : null,
    );
  }

  /// Resolves [url] against [Env.apiBaseUrl]'s origin — an absolute-path
  /// reference (e.g. `/v1/assets/{id}`) replaces that origin's path
  /// entirely per standard URI-resolution semantics (RFC 3986), correct
  /// regardless of whether [Env.apiBaseUrl] itself already includes a
  /// `/v1` segment. A fully-qualified [url] resolves to itself unchanged.
  Uri _resolve(String url) => Uri.parse(Env.apiBaseUrl).resolve(url);

  /// Throws (never returns null/empty) on any failure — callers each map
  /// that into whatever `Result`/fallback shape fits their own context
  /// (a decode failure vs. a "just show a placeholder icon" UI gap are
  /// different enough that one shared error type here wouldn't fit both).
  Future<Uint8List> fetchBytes(String url) async {
    final options = await _optionsFor(url);
    final response = await _plainDio.getUri<List<int>>(
      _resolve(url),
      options: options.copyWith(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null) {
      throw StateError('Asset fetch returned no data: $url');
    }
    return Uint8List.fromList(data);
  }
}
