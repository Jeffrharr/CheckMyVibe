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

command -v python3 >/dev/null || echo "warning: python3 not found — pr-interview's coverage-log validation (scripts/validate-coverage-log.py) will be skipped; everything else still works" >&2

mkdir -p "$TARGET/.checkmyvibe" "$TARGET/.github/workflows" "$TARGET/scripts" "$TARGET/templates"
install -m 0755 "$HERE/scripts/set-status.sh"             "$TARGET/.checkmyvibe/set-status.sh"
install -m 0755 "$HERE/scripts/set-review-status.sh"      "$TARGET/.checkmyvibe/set-review-status.sh"
install -m 0644 "$HERE/templates/checkmyvibe-gate.yml"    "$TARGET/.github/workflows/checkmyvibe-gate.yml"
install -m 0755 "$HERE/scripts/validate-coverage-log.py"  "$TARGET/scripts/validate-coverage-log.py"
install -m 0644 "$HERE/templates/coverage-log.schema.json" "$TARGET/templates/coverage-log.schema.json"
install -m 0755 "$HERE/scripts/post-skill-validate-coverage-log.sh" "$TARGET/scripts/post-skill-validate-coverage-log.sh"
install -m 0644 "$HERE/templates/settings.hooks.json" "$TARGET/templates/settings.hooks.json"

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
  SKILLS_ROOT="$HOME/.claude/skills"
else
  SKILLS_ROOT="$TARGET/.claude/skills"
fi
# /check-my-vibe (orchestrator + gate) plus the interview skill it routes to.
for s in check-my-vibe pr-interview; do
  mkdir -p "$SKILLS_ROOT/$s"
  install -m 0644 "$HERE/skills/$s/SKILL.md" "$SKILLS_ROOT/$s/SKILL.md"
done

cat <<EOF

Installed the CheckMyVibe Gate into: $TARGET
  • .checkmyvibe/set-status.sh        (gitignored — local tooling)
  • .checkmyvibe/set-review-status.sh (gitignored — local tooling)
  • .checkmyvibe/config                (gitignored — edit to set default skills / check names)
  • .github/workflows/checkmyvibe-gate.yml
  • skills -> $SKILLS_ROOT/{check-my-vibe,pr-interview}/SKILL.md
  • scripts/validate-coverage-log.py    (coverage-log validation; needs python3, optional)
  • templates/coverage-log.schema.json
  • scripts/post-skill-validate-coverage-log.sh (optional PostToolUse hook, see below)
  • templates/settings.hooks.json
  • .gitignore                         (added .checkmyvibe/)

Next steps (manual):
  1. Commit the gate workflow (and per-repo skill). The .checkmyvibe/ dir is
     gitignored as local tooling — each developer runs the installer.
  2. Enable branch protection on the default branch and add a REQUIRED status check
     named exactly:  check-my-vibe-protection
       Settings → Branches → Branch protection → Require status checks to pass
  3. Open a PR — the gate arms as 'pending'. Run /check-my-vibe in Claude Code
     to complete the interview and unblock the merge.
  4. Optional: to auto-validate the coverage log after every pr-interview run
     instead of relying on the interviewing model, merge templates/settings.hooks.json
     into .claude/settings.json.
EOF
