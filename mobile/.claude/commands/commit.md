---
description: The only sanctioned way to commit mobile/ changes — runs analyze, a fast test subset, and the flutter-code-reviewer subagent before committing. A root PreToolUse hook blocks raw `git commit` on mobile/** changes without this having run first.
argument-hint: [optional extra commit message context]
allowed-tools: Bash(fvm flutter analyze), Bash(fvm flutter test *), Bash(git status *), Bash(git diff *), Bash(git add *), Bash(git commit *), Bash(git log *), Bash(sha256sum *), Read, Grep, Glob
---

Run the full pre-commit pipeline for the currently staged + unstaged
`mobile/` changes, then commit. Do not skip a step because the diff
"looks small" — the hook enforces this regardless, but the point is to
actually catch problems, not just satisfy the hook.

1. `git status` and `git diff` (staged + unstaged) to see the full scope
   of what's about to be committed. If nothing under `mobile/` changed,
   say so and stop — don't invent a commit.

2. Run `fvm flutter analyze` from `mobile/`. If it's not clean, fix the
   issues (or, if a warning is a deliberate, justified exception, say so
   explicitly) before continuing — do not commit with analyzer errors.

3. Run a fast test subset relevant to the changed files (at minimum:
   `fvm flutter test` for any test file under a changed feature's
   directory tree; the full suite if the change touches `core/`). If a
   test fails, fix the code or the test — never comment out or delete a
   failing test to get past this step.

4. Dispatch the `flutter-code-reviewer` subagent (or, if subagents aren't
   available in this context, apply `.claude/skills/flutter-review-checklist/SKILL.md`
   directly yourself, at the same rigor) against the diff from step 1.
   - If it reports any CONFIRMED finding at high or critical severity,
     stop. Fix the issue, then re-run from step 2 — do not commit past a
     confirmed high/critical finding.
   - PLAUSIBLE or lower-severity findings: surface them to the user in
     your response after committing: don't silently drop them, but don't
     block on them either.

5. Once steps 2-4 pass, write the review-passed marker so the root hook
   allows the commit:
   ```
   cd "$CLAUDE_PROJECT_DIR" && git diff --cached -- mobile > /tmp/kelal-staged.diff 2>/dev/null || true
   git add <the files this commit should include>
   git diff --cached -- mobile | sha256sum | cut -d' ' -f1 > mobile/.claude/.review-passed
   ```
   (Stage files first, then hash the *staged* diff — the hook compares
   against the staged diff at commit time, so the marker must be written
   after staging, not before.)

6. Commit with a Conventional Commits message (`feat:`, `fix:`, `refactor:`,
   `test:`, `chore:`, etc.) summarizing the *why*, not a restatement of the
   diff. Include `$ARGUMENTS` as additional context if provided. **Never**
   add a `Co-Authored-By: Claude`/AI-attribution trailer — explicit
   project rule, not a default to fall back to.

7. Report what was committed and any PLAUSIBLE/lower-severity findings
   from step 4 that the user should know about.

If any step can't be completed (analyze won't pass, a test can't be
fixed, the reviewer keeps finding a real problem), stop and explain why
rather than forcing a commit through.
