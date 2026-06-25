#!/usr/bin/env bash
# install-into.sh — vendor the Understanding Gate into another git repo.
#
# Copies the gate's three moving parts into a target repo so it has no runtime
# dependency on this toolkit (avoids private cross-repo access headaches):
#   • .understanding/set-status.sh             — the shared status writer
#   • .github/workflows/understanding-gate.yml — arms `understanding-check` pending per PR push
#   • the /understanding-check skill           — the local interview
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"  # toolkit root

usage() {
  cat <<'EOF'
Usage: install-into.sh <path-to-target-repo> [--global-skill]

Options:
  --global-skill   install the skill into ~/.claude/skills (one install, all repos)
                   instead of the target repo's .claude/skills
EOF
}

[[ $# -ge 1 ]] || { usage; exit 2; }

TARGET=""; GLOBAL_SKILL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --global-skill) GLOBAL_SKILL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "error: unknown option '$1'" >&2; usage; exit 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

[[ -n "$TARGET" ]] || { usage; exit 2; }
[[ -d "$TARGET/.git" ]] || { echo "error: '$TARGET' is not a git repo" >&2; exit 1; }

mkdir -p "$TARGET/.understanding" "$TARGET/.github/workflows"
install -m 0755 "$HERE/scripts/set-status.sh"          "$TARGET/.understanding/set-status.sh"
install -m 0644 "$HERE/templates/understanding-gate.yml" "$TARGET/.github/workflows/understanding-gate.yml"

if [[ "$GLOBAL_SKILL" -eq 1 ]]; then
  SKILL_DEST="$HOME/.claude/skills/understanding-check"
else
  SKILL_DEST="$TARGET/.claude/skills/understanding-check"
fi
mkdir -p "$SKILL_DEST"
install -m 0644 "$HERE/skills/understanding-check/SKILL.md" "$SKILL_DEST/SKILL.md"

cat <<EOF

Installed the Understanding Gate into: $TARGET
  • .understanding/set-status.sh
  • .github/workflows/understanding-gate.yml
  • skill -> $SKILL_DEST/SKILL.md

Next steps (manual):
  1. Commit the vendored files in the target repo.
  2. Enable branch protection on the default branch and add a REQUIRED status check
     named exactly:  understanding-check
       Settings → Branches → Branch protection → Require status checks to pass
  3. Open a PR — the gate arms as 'pending'. Run /understanding-check in Claude Code
     to complete the interview and unblock the merge.
EOF
