import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared `Hero` tag linking `ComposerPage`'s "Create graphic" button to
/// `CanvasEditorPage`'s `AppBar` title — the one Hero flight this app has
/// (composer -> canvas editor is the only navigation with a natural,
/// single, non-repeated shared element to animate; nothing else in this
/// app's routes has an equivalent). A single static tag is safe here
/// specifically because both source and destination are singletons on
/// screen at once (one composer, one canvas editor), never a list item
/// needing a per-instance tag.
const heroCreateGraphicTag = 'create-graphic-hero';

/// One shared transition, used by every `GoRoute` that wants something more
/// deliberate than go_router/Flutter's platform default (an
/// `AndroidViewController` slide-up on Android, a Cupertino slide on iOS —
/// inconsistent with each other and with this app's own brand feel).
///
/// A fade-through-and-scale: the incoming page fades and scales up from
/// 96% while the outgoing page fades out — Material's "shared axis"/
/// "fade through" pattern, built from Flutter's own `FadeTransition`/
/// `ScaleTransition` rather than pulling in `animations` (a new dependency
/// for a few lines of curve math isn't justified — see mobile/CLAUDE.md's
/// "don't add a dependency unless confirmed genuinely unavailable" rule).
///
/// Doesn't replace every route — only the ones this branch's task
/// specifically calls out (`/canvas-editor`, `/export`) as worth the visual
/// weight of a custom transition; the auth/shell routes keep the platform
/// default, which is the right choice for a first-run login flow that
/// should feel like standard OS chrome, not a branded flourish.
Page<T> buildFadeThroughPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
