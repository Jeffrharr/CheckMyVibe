#!/usr/bin/env bash
# install-into.sh — vendor the CheckMyVibe Gate into another git repo.
#
# Copies the gate's three moving parts into a target repo so it has no runtime
# dependency on this toolkit (avoids private cross-repo access headaches):
#   • .checkmyvibe/set-status.sh             — the shared status writer
#   • .github/workflows/checkmyvibe-gate.yml — arms `check-my-vibe-protection` pending per PR push
#   • the /check-my-vibe skill                 — the local interview
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

mkdir -p "$TARGET/.checkmyvibe" "$TARGET/.github/workflows"
install -m 0755 "$HERE/scripts/set-status.sh"          "$TARGET/.checkmyvibe/set-status.sh"
install -m 0644 "$HERE/templates/checkmyvibe-gate.yml" "$TARGET/.github/workflows/checkmyvibe-gate.yml"

# Config template — never clobber a consumer's existing config.
if [[ ! -f "$TARGET/.checkmyvibe/config" ]]; then
  install -m 0644 "$HERE/templates/config" "$TARGET/.checkmyvibe/config"
fi

# Keep the vendored local tooling out of the consumer's history — set-status.sh
# and config are per-developer (CI uses the published action, not these files).
GITIGNORE="$TARGET/.gitignore"
if [[ -f "$GITIGNORE" ]] && grep -qxF '.checkmyvibe/' "$GITIGNORE"; then
  : # already ignored
else
  { [[ -s "$GITIGNORE" ]] && printf '\n'
    printf '# CheckMyVibe — local gate tooling (vendored per developer, not committed)\n.checkmyvibe/\n'
  } >> "$GITIGNORE"
fi

if [[ "$GLOBAL_SKILL" -eq 1 ]]; then
  SKILL_DEST="$HOME/.claude/skills/check-my-vibe"
else
  SKILL_DEST="$TARGET/.claude/skills/check-my-vibe"
fi
mkdir -p "$SKILL_DEST"
install -m 0644 "$HERE/skills/check-my-vibe/SKILL.md" "$SKILL_DEST/SKILL.md"

cat <<EOF

Installed the CheckMyVibe Gate into: $TARGET
  • .checkmyvibe/set-status.sh     (gitignored — local tooling)
  • .checkmyvibe/config            (gitignored — edit to set a default skill / check name)
  • .github/workflows/checkmyvibe-gate.yml
  • skill -> $SKILL_DEST/SKILL.md
  • .gitignore                     (added .checkmyvibe/)

Next steps (manual):
  1. Commit the gate workflow (and per-repo skill). The .checkmyvibe/ dir is
     gitignored as local tooling — each developer runs the installer.
  2. Enable branch protection on the default branch and add a REQUIRED status check
     named exactly:  check-my-vibe-protection
       Settings → Branches → Branch protection → Require status checks to pass
  3. Open a PR — the gate arms as 'pending'. Run /check-my-vibe in Claude Code
     to complete the interview and unblock the merge.
EOF
