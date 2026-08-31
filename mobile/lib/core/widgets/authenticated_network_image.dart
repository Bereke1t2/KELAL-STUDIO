import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/network/authenticated_asset_client.dart';

/// Fetches and displays a first-party asset by relative URL (e.g.
/// `/v1/assets/{id}`) via [AuthenticatedAssetClient] — the client this app
/// now uses everywhere it displays a backend-served image
/// (`NetworkImageDecoder` for a freshly-generated graphic; this widget for
/// a previously-saved image with no in-memory bytes to show yet, e.g. a
/// `BrandKit` logo the current session never picked itself).
///
/// Deliberately has no `errorBuilder`/`placeholder` widget parameters —
/// every current caller wants the same two fallbacks (a spinner while
/// loading, [fallback] on failure), so a bare required [fallback] plus a
/// hardcoded spinner keeps this simple rather than pre-building
/// configurability nothing yet needs.
///
/// **Reads `getIt<AuthenticatedAssetClient>()` directly, not through a
/// Bloc/use case/repository** — a deliberate exception to the "Blocs call
/// use cases, never repositories" rule (mobile/CLAUDE.md), same reasoning
/// `DecodeGeneratedImageUseCase`'s own doc comment gives for depending on
/// the concrete `NetworkImageDecoder` directly: this is a generic
/// `core/widgets` presentational primitive (the same category as
/// Flutter's own `Image.network`), not feature domain logic, and there's
/// no real/fake data-source split for "fetch these bytes" to preserve —
/// `AuthenticatedAssetClient` behaves identically in both modes.
class AuthenticatedNetworkImage extends StatefulWidget {
  const AuthenticatedNetworkImage({
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String url;
  final BoxFit fit;

  /// Shown in place of the image if the fetch or decode fails — a plain
  /// icon today at every call site, but left as a widget rather than an
  /// `IconData` so a caller isn't forced into that specific shape.
  final Widget fallback;

  @override
  State<AuthenticatedNetworkImage> createState() =>
      _AuthenticatedNetworkImageState();
}

class _AuthenticatedNetworkImageState extends State<AuthenticatedNetworkImage> {
  late Future<Uint8List> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = getIt<AuthenticatedAssetClient>().fetchBytes(widget.url);
  }

  @override
  void didUpdateWidget(covariant AuthenticatedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytesFuture = getIt<AuthenticatedAssetClient>().fetchBytes(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null) return widget.fallback;
        return Image.memory(bytes, fit: widget.fit);
      },
    );
  }
}
