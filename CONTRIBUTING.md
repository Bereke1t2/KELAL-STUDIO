# Contributing

Repo-wide git/PR process. For anything Flutter/Dart-specific (build,
test, architecture), see `mobile/CLAUDE.md` instead — this file is about
how changes move from a local branch to `main`, not what's in them.

## Commits

- [Conventional Commits](https://www.conventionalcommits.org/) —
  `feat:`, `fix:`, `refactor:`, `test:`, `chore:`, `docs:`. Summarize
  *why*, not a restatement of the diff.
- A change under `mobile/` must go through `mobile/.claude/commands/commit.md`
  (`/commit`) — it runs `flutter analyze`, tests, and the
  `flutter-code-reviewer` subagent before committing, and a root
  `PreToolUse` hook (`.claude/settings.json`) blocks a raw `git commit` on
  staged `mobile/**` changes that skip it. Don't work around the hook;
  fix whatever it's blocking.
- Never commit generated files that are gitignored (`*.g.dart`,
  `*.freezed.dart`, `*.config.dart`, `lib/core/l10n/gen/`,
  `lib/core/env/env.g.dart`) — if `git status` shows one of these as
  untracked/modified and about to be staged, that's a `.gitignore` bug to
  fix, not something to force-add.

## Pull requests: stacked, via `gh stack`

Large changes are broken into a **stack** of small, individually
reviewable PRs that build on each other, using the
[`gh stack`](https://gh.io/stacks) extension (already installed —
`gh extension list` shows `github/gh-stack`). Don't open one large PR for
a multi-part change when it can reasonably be stacked instead.

```
# One-time per stack: start it from the trunk (usually main)
gh stack init

# ...or adopt branches that already exist, in bottom-to-top order
gh stack init branch1 branch2 branch3

# Add the next branch on top of the current stack, then commit as normal
# (via /commit for mobile/ changes)
gh stack add feat/composer-idea-input

# Push every branch in the stack and create/update a PR per branch on GitHub
gh stack submit

# Pull remote changes (e.g. after a lower PR in the stack was updated
# from review feedback) back into the rest of the stack
gh stack sync

# Rebase the whole stack after the trunk moves
gh stack rebase

# Once every PR in the stack has merged
gh stack unstack
```

Navigating a stack locally: `gh stack view` (see the whole stack),
`gh stack up` / `gh stack down` (move one branch at a time),
`gh stack top` / `gh stack bottom` (jump to either end),
`gh stack checkout <PR#-or-branch>` (jump to a specific entry).

Rules:
- Each branch in the stack should be one reviewable unit of work — not
  "everything I did today," and not so small it's pure noise. Use
  judgment; when unsure, prefer smaller.
- Every commit on every branch in the stack still goes through `/commit`'s
  review individually — stacking doesn't bypass or batch the review
  requirement, it just changes how the PRs are organized on GitHub.
- Rebase (`gh stack rebase`) rather than merge when picking up trunk
  changes into a stack, to keep history linear and each PR's diff honest.
- Don't force-push over a stack branch another person has already
  reviewed/commented on without flagging it — `gh stack sync`/`rebase`
  are the sanctioned ways to move a stack, not an ad-hoc `git push -f`.

## Review

- `/review` (mobile) or the `flutter-code-reviewer` subagent for a
  standalone look at a diff, any time — see
  `mobile/.claude/skills/flutter-review-checklist/SKILL.md` for the
  rubric (architecture, correctness, performance, edge cases, race
  conditions, bugs, security-strict, test coverage).
- A PR should not be opened with a CONFIRMED high/critical finding still
  outstanding from that rubric — `/commit`'s gate already prevents this at
  the commit level, so a PR built entirely from `/commit`'d commits
  satisfies this by construction.
