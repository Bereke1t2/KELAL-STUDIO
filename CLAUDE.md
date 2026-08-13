# Kelal Studio

Monorepo for Kelal Studio — a bilingual (Amharic/English) AI
content-generation app for Ethiopian businesses. See
`docs/Kelal_Studio_PRD.pdf` for the full product spec.

## Layout

- `mobile/` — the Flutter app (iOS + Android). This is the product's
  primary, load-bearing surface — see `mobile/CLAUDE.md` for everything
  Flutter/Dart-specific (architecture, commands, conventions). Anything
  touching mobile code should read that file, not this one.
- `web/`, `backend/` — planned (React admin/brand-kit portal, Go API),
  **not built yet**. Do not create placeholder code for these unless
  explicitly asked — an empty stub is worse than no directory.
- `docs/` — PRD and reference material.

## Repo-wide rules

See `CONTRIBUTING.md` for the full commit/PR process. Short version:

- Commits use Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:`,
  `chore:`, ...) summarizing *why*, not a restatement of the diff.
- A change under `mobile/` must go through `mobile/.claude/commands/commit.md`
  (`/commit`) — a `PreToolUse` hook (`.claude/settings.json`) blocks a raw
  `git commit` on staged `mobile/**` changes without it. The hook is a
  no-op for changes outside `mobile/`, so it costs nothing today and
  applies automatically to `web/`/`backend/` once they exist and grow
  their own `/commit`-equivalent — don't remove or weaken the hook to work
  around it; fix whatever it's blocking instead.
- PRs are stacked via `gh stack` (already installed), not one-off
  `gh pr create` calls for multi-part work — use `/pr`
  (`.claude/commands/pr.md`) rather than hand-rolling the GitHub CLI
  invocations.
