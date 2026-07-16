#!/usr/bin/env bash
# post-skill-mark-token-usage-start.sh — Claude Code PostToolUse hook.
#
# Wire into .claude/settings.json against the Skill tool (see
# templates/settings.hooks.json), alongside post-skill-validate-coverage-log.sh.
# Fires at the moment check-my-vibe is invoked and records a start marker —
# current line count of the session transcript — so the Stop hook
# (scripts/stop-log-token-usage.sh) knows which slice of the transcript
# belongs to this check-my-vibe run once it finishes.
#
# Filters on the *orchestrator* skill (CHECKMYVIBE_SKILL, default
# check-my-vibe), not pr-interview — the whole point is to capture
# check-my-vibe's PR-resolution and gate-clearing turns too, not just the
# inner interview. A standalone pr-interview run (bypassing check-my-vibe)
# never gets a marker and so never gets token-usage logging; this is a known,
# accepted limitation (see the plan/PR description).
#
# Never fails the session: missing python3, missing config, or unset
# CHECKMYVIBE_COVERAGE_LOG all just skip marker-writing silently.
set -uo pipefail

command -v python3 >/dev/null || exit 0

PAYLOAD="$(cat)"
SKILL="$(python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print(data.get("tool_input", {}).get("skill", ""))
' <<<"$PAYLOAD" 2>/dev/null)"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${CHECKMYVIBE_CONFIG:-$HERE/.checkmyvibe/config}"

ORCHESTRATOR_SKILL="${CHECKMYVIBE_SKILL:-}"
[[ -n "$ORCHESTRATOR_SKILL" ]] || ORCHESTRATOR_SKILL="$(grep -oP '^CHECKMYVIBE_SKILL=\K.*' "$CONFIG" 2>/dev/null)"
[[ -n "$ORCHESTRATOR_SKILL" ]] || ORCHESTRATOR_SKILL="check-my-vibe"

[[ "$SKILL" == "$ORCHESTRATOR_SKILL" ]] || exit 0

LOG_PATH="${CHECKMYVIBE_COVERAGE_LOG:-}"
[[ -n "$LOG_PATH" ]] || LOG_PATH="$(grep -oP '^CHECKMYVIBE_COVERAGE_LOG=\K.*' "$CONFIG" 2>/dev/null)"
[[ -n "$LOG_PATH" ]] || exit 0   # opt-in, same gate as coverage logging itself

python3 "$HERE/scripts/mark-token-usage-start.py" --here "$HERE" <<<"$PAYLOAD"

exit 0
