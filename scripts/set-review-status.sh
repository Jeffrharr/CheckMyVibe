#!/usr/bin/env bash
# set-review-status.sh — write a per-reviewer understanding marker on a PR head commit.
#
# Reviewer-side analogue of set-status.sh. Where set-status.sh writes the single
# author gate (`check-my-vibe-protection`), this writes a per-reviewer marker:
#   context = check-my-vibe-review/<reviewer-login>
# on the PR's head SHA, attributed to the reviewer's own `gh` identity.
#
# A reviewer runs this (via the reviewer interview skill) once they understand the
# change they're approving. The aggregation Action reads these markers + GitHub
# approvals and decides whether the `check-my-vibe-reviews` required check passes —
# that lives separately; this script only records one reviewer's marker.
#
# Markers are per-SHA, so a new push invalidates prior reviewer clearances.
set -euo pipefail

# Configuration — precedence: built-in default < .checkmyvibe/config < environment.
# The config file lives next to this script, so it resolves regardless of CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CHECKMYVIBE_CONFIG:-$SCRIPT_DIR/config}"

# Capture env-provided overrides before sourcing the config (so env wins).
_env_skill="${CHECKMYVIBE_REVIEW_SKILL:-}"
_env_prefix="${CHECKMYVIBE_REVIEW_CONTEXT:-}"
_env_docs="${CHECKMYVIBE_DOCS_URL:-}"

# shellcheck disable=SC1090
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

[[ -n "$_env_skill" ]]  && CHECKMYVIBE_REVIEW_SKILL="$_env_skill"
[[ -n "$_env_prefix" ]] && CHECKMYVIBE_REVIEW_CONTEXT="$_env_prefix"
[[ -n "$_env_docs" ]]   && CHECKMYVIBE_DOCS_URL="$_env_docs"

SKILL="${CHECKMYVIBE_REVIEW_SKILL:-check-my-vibe}"
PREFIX="${CHECKMYVIBE_REVIEW_CONTEXT:-check-my-vibe-review}"
DOCS_URL="${CHECKMYVIBE_DOCS_URL:-https://github.com/Jeffrharr/CheckMyVibe#unblocking-a-pr}"

usage() {
  cat <<'EOF'
Usage: set-review-status.sh <success|failure> [--reviewer <login>] [--sha <sha>] [--pr <num>] [--repo <owner/name>]

Writes a per-reviewer understanding marker on a pull request's head commit:
  context = check-my-vibe-review/<reviewer-login>

  success   reviewer reviewed and understands the change (record their marker)
  failure   revoke this reviewer's marker

Reviewer (default: the authenticated `gh` user — the person running this):
  --reviewer <login>  attribute the marker to this GitHub login

Targeting (first match wins):
  --sha <sha>        write the marker to this commit SHA
  --pr  <num>        resolve the head SHA from this PR number
  (default)          resolve the open PR for the current branch; else HEAD

  --repo owner/name  override the repo (default: $GITHUB_REPOSITORY, else `gh repo view`)

Config (.checkmyvibe/config, overridable by env):
  CHECKMYVIBE_REVIEW_SKILL    slash command shown in the marker message (default: check-my-vibe)
  CHECKMYVIBE_REVIEW_CONTEXT  marker context prefix (default: check-my-vibe-review)
  CHECKMYVIBE_DOCS_URL        the "Details" link on the marker
  CHECKMYVIBE_REVIEWER        default reviewer login (overrides the authenticated user)

Env:
  GH_TOKEN / GITHUB_TOKEN     token used by `gh` (needs `statuses: write`)
  CHECKMYVIBE_CONFIG          path to the config file (default: <script dir>/config)
EOF
}

[[ $# -ge 1 ]] || { usage; exit 2; }

STATE="$1"; shift
case "$STATE" in
  success|failure) ;;
  -h|--help) usage; exit 0 ;;
  *) echo "error: invalid state '$STATE' (expected success|failure)" >&2; usage; exit 2 ;;
esac

SHA=""; PR=""; REPO=""; REVIEWER="${CHECKMYVIBE_REVIEWER:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reviewer) REVIEWER="$2"; shift 2 ;;
    --sha)      SHA="$2";      shift 2 ;;
    --pr)       PR="$2";       shift 2 ;;
    --repo)     REPO="$2";     shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "error: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

command -v gh >/dev/null || { echo "error: GitHub CLI (gh) not found" >&2; exit 1; }

# Resolve reviewer: explicit flag / config → the authenticated gh user.
[[ -n "$REVIEWER" ]] || REVIEWER="$(gh api user --jq .login 2>/dev/null || true)"
[[ -n "$REVIEWER" ]] || { echo "error: could not resolve reviewer login (pass --reviewer)" >&2; exit 1; }

# Resolve repo: explicit flag → CI env → current checkout.
[[ -n "$REPO" ]] || REPO="${GITHUB_REPOSITORY:-}"
[[ -n "$REPO" ]] || REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

# Resolve SHA: explicit flag → from PR number → current-branch PR → HEAD.
if [[ -z "$SHA" && -n "$PR" ]]; then
  SHA="$(gh pr view "$PR" --repo "$REPO" --json headRefOid -q .headRefOid)"
fi
if [[ -z "$SHA" ]]; then
  SHA="$(gh pr view --repo "$REPO" --json headRefOid -q .headRefOid 2>/dev/null || true)"
fi
if [[ -z "$SHA" ]]; then
  SHA="$(git rev-parse HEAD 2>/dev/null || true)"
fi
[[ -n "$SHA" ]] || { echo "error: could not resolve a commit SHA (pass --sha or --pr)" >&2; exit 1; }

CONTEXT="$PREFIX/$REVIEWER"

case "$STATE" in
  success) DESC="Reviewed and understood via /$SKILL by @$REVIEWER" ;;
  failure) DESC="Review understanding revoked by @$REVIEWER" ;;
esac

gh api -X POST "repos/$REPO/statuses/$SHA" \
  -f state="$STATE" \
  -f context="$CONTEXT" \
  -f description="$DESC" \
  -f target_url="$DOCS_URL" >/dev/null

echo "set $CONTEXT=$STATE on $REPO@${SHA:0:12}"
