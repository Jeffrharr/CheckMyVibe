#!/usr/bin/env bash
# stop-log-token-usage.sh — Claude Code Stop hook.
#
# Wire into .claude/settings.json's top-level "Stop" array (see
# templates/settings.hooks.json). Fires on every Stop event in every
# session — must stay cheap when this isn't a check-my-vibe session, hence
# the single file-existence check before doing anything else.
#
# Checks whether a token-usage start marker exists for this session
# (written by scripts/mark-token-usage-start.py when check-my-vibe was
# invoked). If check-my-vibe hasn't signaled completion yet (no
# .checkmyvibe-complete sentinel newer than the marker), the session is
# still in progress — do nothing. Once it has, scripts/finalize-token-usage.py
# computes actual token usage from the transcript slice since the marker,
# merges it into the coverage-log line pr-interview already wrote, writes the
# per-turn companion detail file, and deletes the marker.
#
# Never blocks the session: always exits 0, prints warnings to stderr only.
set -uo pipefail

command -v python3 >/dev/null || exit 0

PAYLOAD="$(cat)"
SESSION_ID="$(python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print(data.get("session_id", ""))
' <<<"$PAYLOAD" 2>/dev/null)"

[[ -n "$SESSION_ID" ]] || exit 0

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKER="$HERE/.checkmyvibe/token-usage/.markers/.marker-$SESSION_ID.json"

[[ -f "$MARKER" ]] || exit 0   # cheap bail — true for almost every Stop event

python3 "$HERE/scripts/finalize-token-usage.py" --here "$HERE" --marker "$MARKER" >&2 || \
  echo "warning: token-usage finalization failed — coverage log entry is unaffected, just missing token_usage" >&2

exit 0
