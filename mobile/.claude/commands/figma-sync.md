---
description: Guided pull of one component/screen from the Kelal Studio Figma design system, following the mandatory figma-design-to-code workflow.
argument-hint: <figma node URL, e.g. https://www.figma.com/design/0dIrGk2LyVEseP6Tz1KxMa/...?node-id=1-2>
---

Pull and implement the Figma node at `$ARGUMENTS` into Flutter code,
following `.claude/skills/flutter-design-system/SKILL.md` and the
`figma-design-to-code` skill's mandatory workflow — do not skip either.

1. If `$ARGUMENTS` has no `node-id` in the URL, stop and ask for a
   node-specific link — do not guess a node id.
2. Load the `figma-design-to-code` skill, then call `get_design_context`
   on the node (fileKey `0dIrGk2LyVEseP6Tz1KxMa` unless the URL specifies
   a different file).
3. Before writing anything: check `lib/core/theme/` and existing
   `features/**/presentation/widgets` for a component that already covers
   this — if one exists, extend/reuse it rather than creating a
   duplicate. State explicitly which you did and why.
4. Map every color/spacing/type token in the response to the matching
   `AppColors`/`AppSpacing`/`AppTypography`/`AppRadius` field using the
   table in `flutter-design-system` — extend that table if this node
   introduces a new token, using the Figma variable name verbatim as the
   Dart field name.
5. For any icon/image in the response: download and commit the actual
   exported asset (the Figma asset URL expires in ~7 days) — never
   hand-write an approximation.
6. Implement as a Flutter widget in the appropriate feature's
   `presentation/widgets/` (or `core/theme` if it's a true cross-feature
   primitive), matching the project's existing widget conventions, not
   the raw React/Tailwind reference output verbatim.
7. Add a golden test scenario for the new component (light + dark, and an
   Amharic-label variant if it displays text) per `flutter-testing`.
8. Report what was pulled, what was reused vs. newly created, and any gap
   between the Figma response and what was actually built (e.g. a Figma
   annotation or interaction hint that couldn't be fully implemented yet).
