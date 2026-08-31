import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/features/brand_kit/domain/repositories/brand_kit_repository.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';

/// One class per use case, single `call()` method — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md.
///
/// **Exists specifically so `DraftsPage`/`DraftsListBloc` never touch
/// `BrandKitRepository` directly.** `DraftCanvasSnapshot.toCanvasScene`
/// (see that method's own doc comment for the full logo-resolution-gap
/// story) needs a `BrandKitRepository` to call, per this branch's design —
/// this use case is the one place that holds that repository so the
/// "Blocs call use cases, never repositories" rule
/// (mobile/CLAUDE.md/mobile/.claude/skills/flutter-architecture/SKILL.md)
/// still holds for the drafts-resume flow, not just every other feature.
/// Not `Result`-wrapped, mirroring `DraftCanvasSnapshot.toCanvasScene`'s
/// own plain-`Future` signature — this can still throw if
/// `Draft.canvasSnapshot.backgroundImagePath` no longer points at a
/// readable file (e.g. the app's documents directory was cleared
/// out-of-band); not given a `Result`/UI-facing error path in this branch,
/// flagged here as a real, if narrow, remaining gap.
@injectable
class ResumeDraftUseCase {
  ResumeDraftUseCase(this._brandKitRepository);

  final BrandKitRepository _brandKitRepository;

  Future<CanvasScene> call(Draft draft) => draft.canvasSnapshot.toCanvasScene(
    brandKitRepository: _brandKitRepository,
  );
}
