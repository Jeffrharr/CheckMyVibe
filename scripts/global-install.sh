#!/usr/bin/env bash
# global-install.sh — install CheckMyVibe without cloning the repo.
#
# Installs the /check-my-vibe skill globally (~/.claude/skills/) and, when a
# target repo path is given, vendors the gate workflow and status writer into
# that repo (no local clone of CheckMyVibe required).
#
# Usage:
#   # Skill only (run via curl):
#   curl -fsSL https://raw.githubusercontent.com/Jeffrharr/CheckMyVibe/main/scripts/global-install.sh | bash
#
#   # Skill + per-repo gate (run via curl with args):
#   curl -fsSL https://...global-install.sh | bash -s -- /path/to/target-repo
#
#   # Or download and run directly:
#   bash global-install.sh [/path/to/target-repo]
set -euo pipefail

# Pin to main until a stable tag is cut.
BASE_URL="https://raw.githubusercontent.com/Jeffrharr/CheckMyVibe/main"

usage() {
  cat <<'EOF'
Usage: global-install.sh [/path/to/target-repo]

Without a target repo: installs the /check-my-vibe skill globally and prints
instructions for setting up the gate in individual repos.

With a target repo: also vendors the gate into that repo —
  • .understanding/set-status.sh
  • .understanding/config          (only if one doesn't already exist)
  • .github/workflows/understanding-gate.yml
EOF
}

TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -*) echo "error: unknown option '$1'" >&2; usage; exit 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

command -v curl >/dev/null || { echo "error: curl is required" >&2; exit 1; }

# --- Skill (always global) ---
SKILL_DEST="$HOME/.claude/skills/check-my-vibe"
mkdir -p "$SKILL_DEST"
curl -fsSL "$BASE_URL/skills/check-my-vibe/SKILL.md" -o "$SKILL_DEST/SKILL.md"
echo "installed skill → $SKILL_DEST/SKILL.md"

# --- Per-repo gate (optional) ---
if [[ -n "$TARGET" ]]; then
  [[ -d "$TARGET/.git" ]] || { echo "error: '$TARGET' is not a git repo" >&2; exit 1; }

  mkdir -p "$TARGET/.understanding" "$TARGET/.github/workflows"

  curl -fsSL "$BASE_URL/scripts/set-status.sh" -o "$TARGET/.understanding/set-status.sh"
  chmod 0755 "$TARGET/.understanding/set-status.sh"
  echo "installed status writer → $TARGET/.understanding/set-status.sh"

  curl -fsSL "$BASE_URL/templates/understanding-gate.yml" \
    -o "$TARGET/.github/workflows/understanding-gate.yml"
  echo "installed gate workflow → $TARGET/.github/workflows/understanding-gate.yml"

  if [[ ! -f "$TARGET/.understanding/config" ]]; then
    curl -fsSL "$BASE_URL/templates/config" -o "$TARGET/.understanding/config"
    echo "installed config template → $TARGET/.understanding/config"
  else
    echo "skipped config (already exists) → $TARGET/.understanding/config"
  fi

  cat <<EOF

Gate installed in: $TARGET

Next steps (manual):
  1. Commit the vendored files in the target repo.
  2. Enable branch protection on the default branch and add a REQUIRED status
     check named exactly:  understanding-check
       Settings → Branches → Branch protection → Require status checks to pass
  3. Open a PR — the gate arms as 'pending'. Run /check-my-vibe in Claude Code
     to complete the interview and unblock the merge.
EOF
else
  cat <<EOF

/check-my-vibe is installed globally and ready in any repo.

To also set up the gate (the CI workflow that arms the check on each push),
run this script again with a target repo path:

  bash global-install.sh /path/to/your-repo

Or use install-into.sh if you have a local clone of CheckMyVibe.
EOF
fi
