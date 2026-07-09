#!/usr/bin/env bash
# install-into.sh — vendor the CheckMyVibe Gate into another git repo.
#
# Copies the gate's moving parts into a target repo so it has no runtime
# dependency on this toolkit (avoids private cross-repo access headaches):
#   • .checkmyvibe/set-status.sh             — the author status writer
#   • .checkmyvibe/set-review-status.sh      — the per-reviewer status writer
#   • .github/workflows/checkmyvibe-gate.yml — arms `check-my-vibe-protection` pending per PR push
#   • the check-my-vibe / pr-interview skills
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

"$HERE/scripts/gate-init.sh" "$TARGET"

if [[ "$GLOBAL_SKILL" -eq 1 ]]; then
  SKILLS_ROOT="$HOME/.claude/skills"
else
  SKILLS_ROOT="$TARGET/.claude/skills"
fi
# /check-my-vibe (orchestrator + gate) plus the interview skill it routes to,
# plus the plugin-only gate initializer (harmless to also vendor here).
for s in check-my-vibe pr-interview checkmyvibe-init; do
  mkdir -p "$SKILLS_ROOT/$s"
  install -m 0644 "$HERE/skills/$s/SKILL.md" "$SKILLS_ROOT/$s/SKILL.md"
done

echo
echo "skills -> $SKILLS_ROOT/{check-my-vibe,pr-interview,checkmyvibe-init}/SKILL.md"
