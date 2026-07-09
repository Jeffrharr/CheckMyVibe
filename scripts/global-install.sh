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
  • .checkmyvibe/set-status.sh
  • .checkmyvibe/set-review-status.sh
  • .checkmyvibe/config          (only if one doesn't already exist)
  • .github/workflows/checkmyvibe-gate.yml
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
command -v python3 >/dev/null || echo "warning: python3 not found — pr-interview's coverage-log validation (scripts/validate-coverage-log.py) will be skipped; everything else still works" >&2

# --- Skills (always global) ---
# /check-my-vibe (orchestrator + gate), the interview skill it routes to, and
# the gate initializer (vendors the gate into a repo without a toolkit clone).
for s in check-my-vibe pr-interview checkmyvibe-init; do
  dest="$HOME/.claude/skills/$s"
  mkdir -p "$dest"
  curl -fsSL "$BASE_URL/skills/$s/SKILL.md" -o "$dest/SKILL.md"
  echo "installed skill → $dest/SKILL.md"
done

# --- Per-repo gate (optional) ---
if [[ -n "$TARGET" ]]; then
  [[ -d "$TARGET/.git" ]] || { echo "error: '$TARGET' is not a git repo" >&2; exit 1; }

  mkdir -p "$TARGET/.checkmyvibe" "$TARGET/.github/workflows"

  curl -fsSL "$BASE_URL/scripts/set-status.sh" -o "$TARGET/.checkmyvibe/set-status.sh"
  chmod 0755 "$TARGET/.checkmyvibe/set-status.sh"
  echo "installed status writer → $TARGET/.checkmyvibe/set-status.sh"

  curl -fsSL "$BASE_URL/scripts/set-review-status.sh" -o "$TARGET/.checkmyvibe/set-review-status.sh"
  chmod 0755 "$TARGET/.checkmyvibe/set-review-status.sh"
  echo "installed reviewer status writer → $TARGET/.checkmyvibe/set-review-status.sh"

  curl -fsSL "$BASE_URL/templates/checkmyvibe-gate.yml" \
    -o "$TARGET/.github/workflows/checkmyvibe-gate.yml"
  echo "installed gate workflow → $TARGET/.github/workflows/checkmyvibe-gate.yml"

  mkdir -p "$TARGET/scripts" "$TARGET/templates"
  curl -fsSL "$BASE_URL/scripts/validate-coverage-log.py" -o "$TARGET/scripts/validate-coverage-log.py"
  chmod 0755 "$TARGET/scripts/validate-coverage-log.py"
  echo "installed coverage-log validator → $TARGET/scripts/validate-coverage-log.py"

  curl -fsSL "$BASE_URL/templates/coverage-log.schema.json" -o "$TARGET/templates/coverage-log.schema.json"
  echo "installed coverage-log schema → $TARGET/templates/coverage-log.schema.json"

  curl -fsSL "$BASE_URL/scripts/post-skill-validate-coverage-log.sh" -o "$TARGET/scripts/post-skill-validate-coverage-log.sh"
  chmod 0755 "$TARGET/scripts/post-skill-validate-coverage-log.sh"
  echo "installed post-skill validation hook → $TARGET/scripts/post-skill-validate-coverage-log.sh"

  curl -fsSL "$BASE_URL/templates/settings.hooks.json" -o "$TARGET/templates/settings.hooks.json"
  echo "installed hook config snippet → $TARGET/templates/settings.hooks.json"

  if [[ ! -f "$TARGET/.checkmyvibe/config" ]]; then
    curl -fsSL "$BASE_URL/templates/config" -o "$TARGET/.checkmyvibe/config"
    echo "installed config template → $TARGET/.checkmyvibe/config"
  else
    echo "skipped config (already exists) → $TARGET/.checkmyvibe/config"
  fi

  # Keep the vendored local tooling out of the consumer's history — set-status.sh
  # and config are per-developer (CI uses the published action, not these files).
  GITIGNORE="$TARGET/.gitignore"
  if [[ -f "$GITIGNORE" ]] && grep -qxF '.checkmyvibe/' "$GITIGNORE"; then
    echo "skipped .gitignore (.checkmyvibe/ already ignored) → $GITIGNORE"
  else
    { [[ -s "$GITIGNORE" ]] && printf '\n'
      printf '# CheckMyVibe — local gate tooling (vendored per developer, not committed)\n.checkmyvibe/\n'
    } >> "$GITIGNORE"
    echo "added .checkmyvibe/ to → $GITIGNORE"
  fi

  cat <<EOF

Gate installed in: $TARGET

Next steps (manual):
  1. Commit the gate workflow (.github/workflows/checkmyvibe-gate.yml). The
     .checkmyvibe/ dir is gitignored as local tooling — each developer installs it.
  2. Enable branch protection on the default branch and add a REQUIRED status
     check named exactly:  check-my-vibe-protection
       Settings → Branches → Branch protection → Require status checks to pass
  3. Open a PR — the gate arms as 'pending'. Run /check-my-vibe in Claude Code
     to complete the interview and unblock the merge.
  4. Optional: to auto-validate the coverage log after every pr-interview run
     instead of relying on the interviewing model, merge templates/settings.hooks.json
     into .claude/settings.json.
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
