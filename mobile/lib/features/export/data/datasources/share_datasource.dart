import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:share_plus/share_plus.dart';

/// Data-source-layer seam over `share_plus` — see
/// `gallery_datasource.dart`'s doc comment on `GalleryDataSource` for the
/// same "mock at the interface boundary" reasoning.
abstract class ShareDataSource {
  /// Invokes the OS Share Sheet with [bytes] attached as a PNG image, plus
  /// [text] (e.g. the selected caption) as the share's accompanying text
  /// where the platform supports it. Resolves once the sheet has been
  /// invoked — see [SharePlusDataSource]'s doc comment on why a
  /// user-dismissed sheet is not surfaced as an error here.
  Future<void> shareImageBytes({required Uint8List bytes, String? text});
}

/// PRD §6.11: hands the exported graphic to the platform's native Share
/// Sheet. "Instagram/TikTok/Telegram as suggested targets" is realized as:
/// the Share Sheet naturally lists every installed app capable of handling
/// an image share (which includes those three if installed) — `share_plus`
/// has no API to force a specific app to appear or to deep-link into one
/// app's own share intent, so this class doesn't attempt either.
@Injectable(as: ShareDataSource)
class SharePlusDataSource implements ShareDataSource {
  const SharePlusDataSource();

  /// Swappable for tests only — mirrors the exact pattern `share_plus`
  /// (`SharePlatform.instance`) and `gal` (`GalPlatform.instance`)
  /// themselves use as their own test seam: a settable static defaulting
  /// to the real platform implementation. `SharePlus.custom(...)` is the
  /// package's own `@visibleForTesting` factory for supplying a fake
  /// `SharePlatform` without touching a real `MethodChannel`. Production
  /// code never sets this.
  @visibleForTesting
  static SharePlus instance = SharePlus.instance;

  static const _exportFileName = 'kelal_studio_export.png';

  @override
  Future<void> shareImageBytes({required Uint8List bytes, String? text}) async {
    // No result-status branching here (ShareResult.status: success /
    // dismissed / unavailable): the OS Share Sheet exposes no distinct
    // "target app not installed" error — it simply omits apps that aren't
    // installed — and a user dismissing the sheet without picking anything
    // is a normal, non-error outcome, not something ExportBloc should
    // surface as a failure. See ExportRepositoryImpl.shareImage's doc
    // comment.
    await instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'image/png', name: _exportFileName),
        ],
        text: text,
      ),
    );
  }
}
