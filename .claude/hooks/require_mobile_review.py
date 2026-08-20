#!/usr/bin/env python3
"""PreToolUse hook: block `git commit` on staged changes under a guarded
area (mobile/, backend/) unless that area's `/commit` command already ran a
passing review for exactly this staged diff.

Design (see the "Enforcement" section of mobile/CLAUDE.md, the backend
docs/ARCHITECTURE.md + README, and the root CLAUDE.md — which explicitly
anticipates this generalizing to web/backend "once they exist and grow
their own /commit-equivalent"):
- No-ops (exit 0) for any Bash command that isn't a `git commit`.
- For each guarded area whose directory exists AND has staged changes,
  requires <area>/.claude/.review-passed to contain the sha256 of the
  currently-staged `git diff --cached -- <area>` output. Blocks (exit 2,
  message to stderr so Claude sees it) if any such area lacks a valid
  marker.
- Fails OPEN (exit 0) for malformed harness input, and for any commit that
  touches no guarded area — this hook is a narrow safety net, not the sole
  line of defense, and must never block work outside the guarded areas
  (today, or in web/ before it grows its own /commit).
- A valid marker is written by the area's /commit (mobile/.claude/commands/
  commit.md, backend/.claude/commands/commit.md) only after that area's
  analyze/lint, tests, and code-review subagent all pass with no confirmed
  high/critical findings — so a valid marker is real evidence a review
  happened for this exact diff, not just that /commit was invoked once.
"""

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

COMMIT_PATTERN = re.compile(r"(^|[;&|]|\btime\b)\s*git\s+(-C\s+\S+\s+)?commit(\s|$)")

# Areas guarded by a /commit review marker. Order is fixed for
# deterministic messages. web/ is intentionally absent until it grows its
# own /commit-equivalent — until then this hook stays a no-op for it.
GUARDED_AREAS = ("mobile", "backend")


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


def staged_diff(root: Path, area: str) -> str:
    return subprocess.run(
        ["git", "diff", "--cached", "--", area],
        cwd=root,
        capture_output=True,
        text=True,
    ).stdout


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

    unreviewed = []
    for area in GUARDED_AREAS:
        area_dir = root / area
        if not area_dir.is_dir():
            # Area doesn't exist yet (e.g. web/) — out of scope for now.
            continue

        diff = staged_diff(root, area)
        if not diff.strip():
            # Nothing staged under this area — this commit doesn't touch
            # it, so it's out of scope for this hook.
            continue

        staged_hash = hashlib.sha256(diff.encode("utf-8")).hexdigest()

        marker_path = area_dir / ".claude" / ".review-passed"
        marker_hash = None
        if marker_path.is_file():
            marker_hash = marker_path.read_text(encoding="utf-8").strip()

        if marker_hash != staged_hash:
            unreviewed.append(area)

    if not unreviewed:
        return 0

    areas = ", ".join(f"{a}/" for a in unreviewed)
    sys.stderr.write(
        f"Blocked: staged changes under {areas} haven't been reviewed for "
        "this exact diff.\n\n"
        "Run /commit instead of a raw `git commit` — each guarded area's "
        "/commit runs that area's analyze/lint, tests, and code-review "
        "subagent, then commits once they pass. (If you already ran /commit "
        "and are seeing this, the staged diff changed after the review ran "
        "— re-run /commit so it reviews the current diff, not a stale one.)\n"
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
