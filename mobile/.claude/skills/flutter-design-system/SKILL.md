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

If a screen needs a component that isn't yet catalogued in this app
(only `Button`/`Card`/basic Material widgets exist as of initial
scaffolding), pull it from Figma per the workflow above rather than
building an ad-hoc equivalent — the whole point of the design system is
that a `Card` built for the composer and a `Card` built for the drafts
list should be the same component.
