#!/usr/bin/env python3
"""Write a token-usage start marker for the check-my-vibe run just invoked.

Called from scripts/post-skill-mark-token-usage-start.sh (a PostToolUse/Skill
hook) with the hook's JSON payload on stdin.

Marker written to
.checkmyvibe/token-usage/.markers/.marker-<session_id>.json — read back by
scripts/finalize-token-usage.py (a Stop hook) once check-my-vibe signals
completion, to know which slice of the transcript to sum.
"""
import argparse
import json
import sys
import time
from pathlib import Path

MARKER_TTL_SECONDS = 7 * 24 * 60 * 60  # opportunistic sweep of abandoned markers


def sweep_stale_markers(markers_dir: Path, now: float) -> None:
    if not markers_dir.is_dir():
        return
    for f in markers_dir.glob(".marker-*.json"):
        try:
            if now - f.stat().st_mtime > MARKER_TTL_SECONDS:
                f.unlink(missing_ok=True)
        except OSError:
            pass


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--here", required=True)
    args = ap.parse_args()

    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    session_id = payload.get("session_id")
    transcript_path = payload.get("transcript_path")
    if not session_id or not transcript_path:
        return 0

    here = Path(args.here)
    markers_dir = here / ".checkmyvibe" / "token-usage" / ".markers"
    markers_dir.mkdir(parents=True, exist_ok=True)

    now = time.time()
    sweep_stale_markers(markers_dir, now)

    tpath = Path(transcript_path)
    transcript_line_count = 0
    if tpath.exists():
        with tpath.open("r", encoding="utf-8", errors="replace") as fh:
            transcript_line_count = sum(1 for _ in fh)

    marker = {
        "session_id": session_id,
        "transcript_path": str(tpath),
        "transcript_line_count_at_start": transcript_line_count,
        "created_at_epoch": int(now),
    }

    marker_path = markers_dir / f".marker-{session_id}.json"
    marker_path.write_text(json.dumps(marker, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
