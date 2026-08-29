import 'dart:typed_data';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/export/domain/entities/export_failure.dart';

/// PRD §6.11: save the exported graphic to the device gallery and/or hand
/// it to the OS Share Sheet. Both methods take already-rendered PNG bytes
/// (`RenderEngine.exportPng(scene)`'s output), never a `CanvasScene`
/// itself — `RenderEngine` is a Flutter-aware `core/` singleton, not a
/// domain-purity-safe type, so the paint step happens in presentation
/// (`ExportBloc`) before calling down into this repository, keeping
/// `domain/` itself free of `dart:ui`/`flutter/rendering` imports.
abstract class ExportRepository {
  /// Writes [pngBytes] to the device's photo gallery via `gal`, requesting
  /// permission first if not already granted.
  Future<Result<ExportFailure, void>> saveToGallery(Uint8List pngBytes);

  /// Hands [pngBytes] (plus optional [text], e.g. the selected caption) to
  /// the OS Share Sheet via `share_plus`. Resolves to `Ok` once the share
  /// sheet has been invoked, regardless of which app (if any) the user
  /// picked or whether they dismissed it — see `ExportRepositoryImpl`'s
  /// doc comment for why a dismissed sheet is not a failure.
  Future<Result<ExportFailure, void>> shareImage({
    required Uint8List pngBytes,
    String? text,
  });
}
