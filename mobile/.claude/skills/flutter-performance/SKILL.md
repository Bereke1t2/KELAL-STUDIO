---
name: flutter-performance
description: Rebuild-avoidance, canvas/image memory management, and app-size rules for the Kelal Studio Flutter app, with specific guidance for the image/canvas-heavy composer and editor screens on low-end Android devices. Use whenever building a widget that rebuilds on state changes, anything touching images or the render engine, or before a release build.
---

# Flutter Performance

Target device floor is low (Android `minSdk 24` — the lowest Flutter
3.44.4's own tooling permits; see mobile/CLAUDE.md's decisions log),
common low-end/older hardware in the target market per the PRD — "works
fine on my dev machine's emulator" is not sufficient evidence a screen
performs acceptably.

## Rebuild avoidance

- `const` constructors everywhere the lint (`very_good_analysis`) allows —
  don't suppress the lint instead of adding `const`.
- Prefer `BlocSelector`/`context.select` over a broad `BlocBuilder` on an
  entire state object when a widget only needs one field — a `BlocBuilder`
  on the whole `LoginState` rebuilds the email field's container on every
  keystroke-driven state change even if only the button needs to change.
- `ListView.builder`/`SliverList` for anything unbounded, with a stable
  `ValueKey` per item; set `itemExtent`/`prototypeItem` when items are a
  uniform height to skip layout measurement.

## Canvas/image memory (the composer and canvas editor specifically)

This is the area most likely to actually crash a low-RAM device, not just
feel slow:

- **Decode once, repaint many.** `core/render_engine` takes a decoded
  `ui.Image` in `CanvasScene` — never decode an image inside a paint call.
  If a slider/adjustment changes, that should trigger a repaint (cheap),
  not a redecode (expensive) — this is exactly why the canvas editor's
  Bloc uses `bloc_concurrency`'s `restartable()` (see
  `flutter-state-management`): cancel-and-restart is only cheap if what's
  being restarted is a repaint, not a decode.
- **Edit against a downscaled proxy; export at full resolution.** Per PRD
  §6.9: don't hold several full-resolution bitmaps in memory during
  interactive editing. Apply the user's transform (position, scale) to
  the full-resolution asset only at export time via
  `RenderEngine.exportPng` — the interactive phase should never touch the
  full-res image.
- Decode images at their **display** resolution (`ResizeImage` or
  equivalent), not source resolution, when the full source resolution
  isn't actually needed on screen.
- Dispose `ui.Image`/`Picture` objects you created (see
  `RenderEngine.exportPng`'s explicit `.dispose()` calls) — don't rely on
  GC timing for large image buffers on a memory-constrained device.

## DevTools workflow

Profile in **profile mode** (`flutter run --profile`), not debug — debug
mode's overhead makes relative comparisons meaningless. Use the
Performance view's "Track widget builds/layouts/paints" to find the
actual rebuild source before optimizing blind, and the Memory view's
allocation tracking specifically when investigating anything
canvas/image-related.

## App size & startup

- Release builds always include `--split-per-abi` (Android) —
  significant per-download size reduction, effectively free.
- Font subsetting: only `assets/fonts/NotoSansEthiopic-Regular.ttf`'s
  Ethiopic range is actually needed at runtime beyond basic Latin — if
  app size becomes a concern, subset aggressively, but never drop
  Ethiopic glyph coverage to save space (see
  `flutter-ethiopic-typography`'s "never render a missing glyph as an
  empty box" rule — that's a harder constraint than size).
- Defer non-critical initialization (analytics, non-essential SDKs) to
  after first frame, not inside `bootstrap()`/`main()` before `runApp()` —
  see `lib/bootstrap.dart`'s existing comment on this.
