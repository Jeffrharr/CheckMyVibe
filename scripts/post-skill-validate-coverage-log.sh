#!/usr/bin/env bash
# post-skill-validate-coverage-log.sh — Claude Code PostToolUse hook.
#
# Wire this into .claude/settings.json against the Skill tool (see
# templates/settings.hooks.json) so the coverage log gets validated
# automatically after pr-interview runs, instead of relying on the
# interviewing model to remember to run the validator itself.
#
# Reads the PostToolUse hook payload from stdin, only acts when the skill
# invoked was pr-interview, and never fails the session — a missing
# python3, missing log, or validation error all just print a warning.
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

[[ "$SKILL" == "pr-interview" ]] || exit 0

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${CHECKMYVIBE_CONFIG:-$HERE/.checkmyvibe/config}"
LOG_PATH="${CHECKMYVIBE_COVERAGE_LOG:-}"
[[ -n "$LOG_PATH" ]] || LOG_PATH="$(grep -oP '^CHECKMYVIBE_COVERAGE_LOG=\K.*' "$CONFIG" 2>/dev/null)"
[[ -n "$LOG_PATH" ]] || exit 0
[[ -f "$HERE/$LOG_PATH" || -f "$LOG_PATH" ]] || exit 0

VALIDATOR="$HERE/scripts/validate-coverage-log.py"
[[ -f "$VALIDATOR" ]] || exit 0

python3 "$VALIDATOR" "$LOG_PATH" >&2 || echo "warning: coverage log validation failed after pr-interview — see above" >&2

exit 0
