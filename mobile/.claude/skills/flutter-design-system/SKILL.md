---
name: flutter-design-system
description: How to pull and implement components from the Kelal Studio Figma design system correctly — mandatory get_design_context workflow, the Figma-token-to-Dart-token mapping, and the reuse-before-recreate rule. Use before building any new screen, component, or visual element, and whenever a Figma URL or node is mentioned.
---

# Flutter Design System

## The design system is real — use it, don't approximate it

The Figma file (`0dIrGk2LyVEseP6Tz1KxMa`, "Kelal Studio Design System")
has populated Color, Typography, and Spacing/Radius foundations plus 12+
components (including a bottom navigation bar) — it is **not** a
placeholder despite its cover page undersizing it. Never invent a color,
size, or component shape "in the spirit of" the design system when the
real value is one `get_design_context` call away.

## Mandatory workflow for any new screen/component

1. Load the `figma-design-to-code` skill and call `get_design_context` on
   the specific node — never guess from a screenshot or from memory of a
   similar component elsewhere in the app.
2. **Check `lib/core/theme/` and existing feature widgets first.** If a
   `Button`, `Card`, spacing value, or color already exists as a token or
   shared widget, reuse it — don't regenerate an equivalent from the
   Figma response's raw Tailwind/hex output.
3. Map every Figma variable to the matching `AppColors`/`AppTypography`/
   `AppSpacing`/`AppRadius` field by name (see the table below) — never
   hardcode a hex value or raw pixel number in a widget.
4. If the component needs a token that doesn't exist yet in
   `core/theme/app_colors.dart` (e.g. a new semantic color), add it there
   with the exact Figma variable name as the Dart field name, don't
   invent a new naming convention.
5. Icons/images from Figma: use the exported asset (download and commit
   the bytes, or wire to a real data source) — never hand-write an
   `<svg>`/`Path` approximation of an icon you don't have vector data for.

## Figma → Dart token mapping (extend this table as new tokens appear)

| Figma variable | Dart field |
|---|---|
| `bg/canvas` | `AppColors.bgCanvas` |
| `bg/surface` | `AppColors.bgSurface` |
| `bg/surface-raised` | `AppColors.bgSurfaceRaised` |
| `bg/inverse` | `AppColors.bgInverse` |
| `bg/brand-subtle` | `AppColors.bgBrandSubtle` |
| `bg/accent-subtle` | `AppColors.bgAccentSubtle` |
| `bg/disabled` | `AppColors.bgDisabled` |
| `border/default` | `AppColors.borderDefault` |
| `border/subtle` | `AppColors.borderSubtle` |
| `border/strong` | `AppColors.borderStrong` |
| `border/focus` | `AppColors.borderFocus` |
| `border/error` | `AppColors.borderError` |
| `border/brand` | `AppColors.borderBrand` |
| `text/primary`, `/secondary`, `/tertiary` | `AppColors.textPrimary/Secondary/Tertiary` |
| Feedback success/warning/error/info `{bg,border,text}` | `AppColors.success*/warning*/error*/info*` |
| `spacing/*` | `AppSpacing.*` (xxs..xxxxxl) |
| `radius/*` | `AppRadius.*` (none/sm/md/lg/xl/full) |
| Type scale (Display/Title/Body/Body Small/Label/Caption/Button Label) | `AppTypography.*` |
| "Destructive (fill)" / Default swatch (not a bound Figma variable, node `9:442`) | `AppColors.interactiveDestructiveDefault` |

## Finding a node when you don't already have its node-id

`get_metadata` called with no `nodeId` ("list top-level pages") is
**unreliable for this file** — it only ever returns `0:1: Cover`, even
though the file has many more canvases. Don't take that listing as
authoritative. What actually works: canvases and any node whose id you
already know are directly fetchable via `get_metadata`/`get_design_context`
with an explicit `nodeId`, regardless of whether the lister mentioned them.

Canvases in this file follow a `Components / <Name>` vs. `Screens /
<Name>` naming split — the former is the real, complete component
definition; the latter is that component as used in an actual app screen
mockup (sometimes under-specified, see the bottom-nav caveat below). If
you need a node you don't have the id for, don't guess blindly — start
from one of the known-good ids below (same file) and search nearby
buckets, or ask for a specific `node-id` URL rather than burning many
calls on speculative ids.

### Component node ids pulled so far (branch 1, design-system foundation)

| Component | Canvas / node | Notes |
|---|---|---|
| Button | `14:2` (`Style=Primary, State=Default`) | Fragment only — no canvas backdrop/title found; already covered by existing `ElevatedButtonThemeData`. |
| Text Field | title only at `17:2` ("Text Input"); actual field mockup not found as a dedicated component | Used `52:7` instead — real "notched floating label" field from Screens / Onboarding & Auth → Sign Up, which is exactly Material's `OutlineInputBorder` + `labelText` behavior. |
| Chip / Tag | `18:2` (Default), `18:4` (Selected) | Figma calls it "Badge". |
| Segmented Control | **not found** | Swept a wide node-id range with no hit — see the doc comment on `AppSegmentedControl` (`lib/core/widgets/segmented_control.dart`). Built from `AppChip`-equivalent tokens instead; re-derive from Figma if this component is ever added to the file. |
| Loading Indicator | `27:2` (`Type=Spinner, Size=Default`) | Companion pattern `Components / Skeleton Loader` at `44:2` (content-shaped placeholders) — not used yet, flagged for the drafts-list/generation-result branch. |
| Empty State | `45:2` (canvas), variants `45:6` / `45:13` | Both variants share one structure. |
| Inline Error Banner | Color Foundations `Color — Feedback`, node `11:4`/`11:11` | Explicitly documented in-file as powering "Toast/Banner and Badge components directly" (node `11:3`) — this **is** the intended source, not a fallback. |
| Dialog / Bottom Sheet shell | `42:2` (canvas "Modal & Sheet"), Bottom Sheet at `42:6`, Centered Dialog at `42:15` | One canvas, two shapes. |
| Avatar / Logo tile | `48:2` (canvas "Avatar & Logo Tile"), states at `48:6`/`48:9`/`48:13`/`48:18` | Square `radius-md` tile, not a circle. |
| Bottom Navigation | `37:2` (canvas), tab row at `37:62`, dark-mode instances at `40:92`+ | See the Pages-tab caveat immediately below. |

### Bottom navigation: Components page vs. Pages tab

Confirmed first-hand: the Pages tab (`Screens / Home & Dashboard`, node
`58:2`) renders the bottom nav in every screen as a bare placeholder — a
frame literally named "Frame" containing one text node named "Nav" (e.g.
`58:18`, `58:39`, `58:51`), with none of the real pill/FAB/active-state
detail. The Components page (`37:2`) has the actual definition. Always
build from the Components-page node; treat the Pages-tab version as a
layout placeholder only, per the explicit instruction that started this
sweep.

## Dark mode

A Light/Dark semantic collection exists in Figma for every token above.
`AppColors.dark` was seeded during initial scaffolding from the light
values plus the same primitive ramps, but only a subset of dark-mode
values (backgrounds, borders, interactive states) were pulled directly —
feedback-color and text-color dark values were **derived**, not pulled
1:1 (see the doc comment on `AppColors.dark`). Before shipping a screen
that will actually be seen in dark mode, pull the real Figma dark-mode
node for that component and correct any derived value that's wrong rather
than assuming the seed guess was exact.

## Don't guess at missing components

If a screen needs a component that isn't yet catalogued in this app, pull
it from Figma per the workflow above rather than building an ad-hoc
equivalent — the whole point of the design system is that a `Card` built
for the composer and a `Card` built for the drafts list should be the
same component.

As of the design-system-foundation branch, `lib/core/widgets/` has:
`PrimaryButton`, `AppTextField`, `AppChip`, `AppSegmentedControl`,
`LoadingIndicator`, `EmptyState`, `ErrorBanner`, `AppBottomSheet`/
`AppDialog`, `BrandAvatar`, `BottomNavBar`, and the `showErrorSnackBar`
helper — check there (and the table above for their source node ids)
before building a new equivalent from scratch.
