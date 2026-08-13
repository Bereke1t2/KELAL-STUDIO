---
description: Standalone review of the current mobile/ diff against flutter-review-checklist — no commit, for mid-task sanity checks.
argument-hint: [optional focus area, e.g. "just security" or "the canvas editor changes"]
allowed-tools: Bash(git diff *), Bash(git status *), Bash(fvm flutter analyze), Read, Grep, Glob
---

Review the current `mobile/` working-tree diff (staged + unstaged) against
`.claude/skills/flutter-review-checklist/SKILL.md` — the same rubric
`/commit` uses, run standalone with no commit at the end.

If `$ARGUMENTS` names a focus area, still run the full checklist but
prioritize and elaborate on that section; don't skip the other sections
entirely.

1. `git diff` to see the actual changes (staged + unstaged) under `mobile/`.
2. Run `fvm flutter analyze` and fold any issues into the correctness section.
3. Work through every section of `flutter-review-checklist` against the
   actual diff — architecture, correctness/bugs, race conditions,
   performance, edge cases, security (strict), test coverage, and
   Ethiopic/i18n correctness if text rendering is touched.
4. Report findings using the same CONFIRMED/PLAUSIBLE severity distinction
   the checklist defines, ranked most-severe first. An empty findings list
   is a fine, expected outcome for a clean diff — don't manufacture
   nitpicks to justify having run the review.

This does not write the review-passed marker and does not commit —
use `/commit` when you're ready to do both.
