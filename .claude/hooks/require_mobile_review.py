#!/usr/bin/env python3
"""PreToolUse hook: block `git commit` on staged mobile/** changes unless
mobile/.claude/commands/commit.md (`/commit`) already ran a passing review
for exactly this staged diff.

Design (see the "Enforcement" section of mobile/CLAUDE.md and the plan
this repo was scaffolded from):
- No-ops (exit 0) for any Bash command that isn't a `git commit`, and for
  any `git commit` whose staged diff doesn't touch mobile/** — this hook
  must never block work outside mobile/, today or once web/backend exist.
- Blocks (exit 2, message to stderr so Claude sees it) a `git commit` that
  touches mobile/** unless mobile/.claude/.review-passed contains the
  sha256 of the currently-staged `git diff --cached -- mobile` output.
- The marker is written by /commit (see mobile/.claude/commands/commit.md)
  only after `flutter analyze`, a test run, and the flutter-code-reviewer
  subagent all pass with no confirmed high/critical findings — so a valid
  marker is real evidence a review happened for this exact diff, not just
  that /commit was invoked at some point in the past.
"""

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

COMMIT_PATTERN = re.compile(r"(^|[;&|]|\btime\b)\s*git\s+(-C\s+\S+\s+)?commit(\s|$)")


def repo_root() -> Path:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
        return Path(out.stdout.strip())
    except Exception:
        return Path.cwd()


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        # Malformed input from the harness — fail open. This hook is a
        # narrow safety net, not the sole line of defense; never let a
        # parsing bug here block unrelated work.
        return 0

    if payload.get("tool_name") != "Bash":
        return 0

    command = (payload.get("tool_input") or {}).get("command", "") or ""
    if not COMMIT_PATTERN.search(command):
        return 0

    root = repo_root()
    mobile_dir = root / "mobile"
    if not mobile_dir.is_dir():
        return 0

    diff = subprocess.run(
        ["git", "diff", "--cached", "--", "mobile"],
        cwd=root,
        capture_output=True,
        text=True,
    ).stdout

    if not diff.strip():
        # Nothing staged under mobile/ — this commit doesn't touch mobile,
        # so it's out of scope for this hook entirely.
        return 0

    staged_hash = hashlib.sha256(diff.encode("utf-8")).hexdigest()

    marker_path = mobile_dir / ".claude" / ".review-passed"
    marker_hash = None
    if marker_path.is_file():
        marker_hash = marker_path.read_text(encoding="utf-8").strip()

    if marker_hash == staged_hash:
        return 0

    sys.stderr.write(
        "Blocked: staged changes under mobile/ haven't been reviewed for "
        "this exact diff.\n\n"
        "Run /commit instead of a raw `git commit` — it runs `flutter "
        "analyze`, tests, and the flutter-code-reviewer subagent, then "
        "commits once they pass. (If you already ran /commit and are "
        "seeing this, the staged diff changed after the review ran — "
        "re-run /commit so it reviews the current diff, not a stale one.)\n"
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
