---
description: Open or update a stacked PR for the current branch via `gh stack`, per CONTRIBUTING.md — never a plain `gh pr create` for a change that should be stacked.
argument-hint: [new branch name, if starting the next entry in the stack]
allowed-tools: Bash(git status *), Bash(git branch *), Bash(git log *), Bash(gh stack *), Bash(gh pr *)
---

Open or update a stacked pull request for the current work, following
`CONTRIBUTING.md`'s stacked-PR process — do not fall back to a plain
`gh pr create` for a change that's part of (or should start) a stack.

1. `git status` and `git log` to confirm the current branch's commits are
   real, intentional commits — not uncommitted work. If there's
   uncommitted work under `mobile/`, stop and say to run `/commit` first;
   don't push unreviewed changes.

2. Check whether a stack already exists here (`gh stack view`). Three
   cases:
   - **No stack yet, and this is the first branch of a multi-part
     change**: `gh stack init` (targeting the trunk, usually `main`).
   - **A stack exists and `$ARGUMENTS` names a new branch**: `gh stack add
     $ARGUMENTS` to add the next entry on top of the current stack, *then*
     make/commit the change there via `/commit` before continuing — don't
     add an empty branch and submit it.
   - **A stack exists and the current branch is already part of it, with
     new commits since the last submit**: skip straight to step 3.

3. `gh stack submit` — pushes every branch in the stack and creates/updates
   one PR per branch on GitHub.

4. Report the PR URL(s) created/updated, and the current stack shape
   (`gh stack view` output) so the user can see the whole chain at a
   glance.

If the change is a genuine one-off (not part of a larger sequence),
`gh stack init` on a single branch and `gh stack submit` still works fine
for it — it degrades to an ordinary single PR. Don't hand-roll `gh pr
create` as a shortcut; keep everything going through `gh stack` so the
tooling's bookkeeping (stack metadata, PR base branches) stays consistent
for whatever gets stacked on top of this later.
