---
description: Accessibility pass — contrast, tap targets, screen-reader labels, font scaling — against the app's real design tokens and NFRs.
argument-hint: [optional screen/widget to focus on]
allowed-tools: Read, Grep, Glob, Bash(fvm flutter analyze)
---

Audit accessibility for `$ARGUMENTS` (or the whole `lib/features/` tree if
unspecified) against the concrete, testable NFRs this project actually
has — not a generic a11y checklist:

1. **Tap targets** — every `GestureDetector`/`InkWell`/button-like widget
   must meet `AppSpacing.minTapTarget` (48px), per the design system's own
   explicit NFR ("min 44-48px tap target... for low-end Android devices").
   Grep for interactive widgets with an explicit smaller `SizedBox`/
   `constraints` and flag them.
2. **Contrast** — text/background color pairs must come from
   `AppColors`'s matched semantic pairs (e.g. `textPrimary` on
   `bgSurface`, `errorText` on `errorBg`) — flag any place a color is
   paired with a background it wasn't designed against (e.g. `textTertiary`
   directly on `bgInverse`), since that's exactly how a low-contrast bug
   gets introduced even when every individual color came from the design
   system.
3. **Screen-reader labels** — every icon-only button or non-text
   interactive element needs a `Semantics`/`tooltip`/`semanticLabel`.
   Flag `IconButton`s with no `tooltip` and custom `GestureDetector`s
   wrapping icon-only content with no `Semantics` wrapper.
4. **Font scaling** — flag any `Text` widget using a hardcoded pixel
   height/width constraint likely to clip text under a large system font
   scale (e.g. a fixed-height `SizedBox` wrapping `Text` instead of
   `ConstrainedBox`/flexible sizing), and confirm `MediaQuery.textScaler`
   isn't being overridden/clamped without a stated reason.
5. **Amharic-specific**: confirm any audited text respects
   `AppTypography.lineHeightMultiplier` (1.55) rather than a tighter
   override — a cramped Amharic line height is both an a11y and a
   typography-correctness issue (see `flutter-ethiopic-typography`).

Report findings as concrete file:line issues, not general reminders —
"this button might be small" isn't actionable; "this button
(`lib/features/x/presentation/widgets/y.dart:42`) is 36px, below the
48px `AppSpacing.minTapTarget` floor" is.
