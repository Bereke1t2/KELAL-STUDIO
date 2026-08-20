---
description: The only sanctioned way to commit backend/ changes — runs gofmt, go vet, golangci-lint, the test suite, and a code-review pass before committing. A root PreToolUse hook blocks raw `git commit` on backend/** changes without this having run first.
argument-hint: [optional extra commit message context]
allowed-tools: Bash(gofmt *), Bash(go vet *), Bash(go build *), Bash(go test *), Bash(golangci-lint *), Bash(make *), Bash(git status *), Bash(git diff *), Bash(git add *), Bash(git commit *), Bash(git log *), Bash(sha256sum *), Read, Grep, Glob
---

Run the full pre-commit pipeline for the currently staged + unstaged
`backend/` changes, then commit. Do not skip a step because the diff
"looks small" — the hook enforces this regardless, but the point is to
actually catch problems, not just satisfy the hook.

All commands run from `backend/` (that's where the Makefile lives). `make
check` runs the fmt/vet/test gates in one shot; run the individual
commands below when you need to iterate on a single gate.

1. `git status` and `git diff` (staged + unstaged) to see the full scope
   of what's about to be committed. If nothing under `backend/` changed,
   say so and stop — don't invent a commit.

2. Run `gofmt -l .` from `backend/`. If it lists any file, run `gofmt -w
   .` to fix formatting before continuing — do not commit unformatted
   code. (`make fmt-check` is the same gate.)

3. Run `go vet ./...` and `golangci-lint run` from `backend/`. Fix what
   they report. If a lint finding is a deliberate, justified exception,
   add a scoped `//nolint:<linter> // <reason>` and say so explicitly —
   never blanket-disable a linter to get past this step.

4. Run the tests: `go test -race ./...` from `backend/` (or `make test`
   for coverage too). If a test fails, fix the code or the test — never
   comment out, skip, or delete a failing test to get past this step.

5. Dispatch a code-review subagent against the diff from step 1 (if
   subagents aren't available, apply the checklist below yourself, at the
   same rigor). Review specifically for the backend's load-bearing rules
   (see `docs/ARCHITECTURE.md`):
   - **Layering:** `domain.go`/`service.go` import no `gin` or `gorm`; Gin
     only in `handler.go`/`routes.go`; GORM only in `repository.go`. No
     feature package imports another feature package.
   - **Errors are values:** every failure crossing a public API is an
     `*apperror.Error` returned (never a panic across a boundary); handlers
     render via `httpx.Fail`.
   - **Provider abstraction:** no feature calls an AI provider directly —
     only through `internal/platform/provider`.
   - **No secrets:** no provider key, JWT secret, or credential added to
     committed code (they come from env via `internal/platform/config`).
   - **Open questions:** no PRD open question silently resolved — flagged
     in code and in `docs/OPEN_QUESTIONS.md` instead (register-verification,
     job-result-field, OQ-02/05/13/19/20, queue-driver, etc.).
   - **Mock parity:** if a repository port changed, both `repository.go`
     and `repository_mock.go` implement it.
   - Plus the usual: correctness, error paths, SQL-injection / `context`
     propagation, race safety, and test coverage of the change.
   - If it reports any CONFIRMED finding at high or critical severity,
     stop. Fix the issue, then re-run from step 2 — do not commit past a
     confirmed high/critical finding. PLAUSIBLE or lower-severity findings:
     surface them to the user after committing; don't silently drop them,
     but don't block on them either.

6. Once steps 2-5 pass, stage the files and write the review-passed marker
   so the root hook allows the commit:
   ```
   cd "$CLAUDE_PROJECT_DIR"
   git add <the files this commit should include>
   git diff --cached -- backend | sha256sum | cut -d' ' -f1 > backend/.claude/.review-passed
   ```
   (Stage files first, then hash the *staged* diff — the hook compares
   against the staged diff at commit time, so the marker must be written
   after staging, not before. If you stage more files afterward, rewrite
   the marker.)

7. Commit with a Conventional Commits message (`feat:`, `fix:`,
   `refactor:`, `test:`, `chore:`, etc.) summarizing the *why*, not a
   restatement of the diff. Include `$ARGUMENTS` as additional context if
   provided. **Never** add a `Co-Authored-By: Claude`/AI-attribution
   trailer — explicit project rule, not a default to fall back to.

8. Report what was committed and any PLAUSIBLE/lower-severity findings
   from step 5 that the user should know about.

If any step can't be completed (vet/lint won't pass, a test can't be
fixed, the reviewer keeps finding a real problem), stop and explain why
rather than forcing a commit through.
