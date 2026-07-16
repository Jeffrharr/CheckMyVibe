---
name: check-my-vibe
description: Walk through a pull request to confirm the change is understood, then clear the relevant merge gate — the author's or a reviewer's.
---

<!--
  Ships with the CheckMyVibe toolkit. The installer OVERWRITES the installed copy of this
  skill on every update, so edits here won't survive. Don't customize the interview by
  editing this orchestrator — create your own interview skill and point
  CHECKMYVIBE_INTERVIEWER (in .checkmyvibe/config) at it. The installer never touches a
  skill it didn't install.
-->

# Check My Vibe

You are helping whoever's running this get a pull request across the finish line — author
or reviewer, it doesn't matter which for the *interview*: since the code in these PRs is
AI-generated, both roles are confirming a human actually understands what shipped, using
the same interview. What differs is which gate gets cleared: the PR author clears the
single author gate; anyone else clears their own per-reviewer marker, since a team may
require several people to each independently confirm understanding.

This is private and local. Do not post anything to GitHub except the final status write.

## 1. Identify the PR and the role

- If the user passed a PR number, use it. Otherwise resolve the PR for the current branch:
  `gh pr view --json number,title,url,headRefOid,baseRefName,author,body`
- If there is no open PR, stop and tell the user to open one first — every gate here keys
  on the PR's head commit, so there is nothing to clear without a PR.
- Determine who's invoking: `gh api user --jq .login`.
- Compare that login (case-insensitive) against the PR's author (`.author.login`):
  - **Author mode** — invoker is the PR's author.
  - **Reviewer mode** — invoker is not the author.

If `gh api user` fails (e.g. no auth), ask the user directly which mode applies rather
than guessing.

## 2. Run the interview

Both modes use the same interview skill — kept swappable so a team can customize how
people are questioned without touching the gate logic here.

- Default: **`pr-interview`**.
- Override: if `.checkmyvibe/config` (or the environment) sets `CHECKMYVIBE_INTERVIEWER`,
  use that skill name instead:
  `cat .checkmyvibe/config 2>/dev/null | grep CHECKMYVIBE_INTERVIEWER`

Invoke that skill, passing the PR number, and let it run to completion. It loads the diff,
interviews whoever's running it, and reports back a confidence profile of whether they
understand the change. Carry that into the next step.

If the configured interview skill isn't available, tell the user how to install it, then
fall back to interviewing them yourself — cover at least: what & why, blast radius, edge
cases & failure modes, testing, and rollback / risk.

## 3. Decide

When the interview is done:

- Give a short, specific summary of what you heard — what's known, what the risks are,
  and any open questions the interview surfaced.
- If a genuinely load-bearing question is unresolved, say what it is and offer to keep
  going. Don't block on trivia; do block on things that could cause a real incident.
- Ask for explicit confirmation, phrased for the mode:
  - Author: **"Ready to mark this PR as understood and unblock merge? (yes/no)"**
  - Reviewer: **"Ready to mark yourself as having reviewed and understood this PR? (yes/no)"**

## 4. Clear the gate

On an explicit "yes", flip the matching check via the vendored writer:

- Author mode:
  ```
  .checkmyvibe/set-status.sh success --pr <num>
  ```
- Reviewer mode:
  ```
  .checkmyvibe/set-review-status.sh success --pr <num>
  ```
  (writes `check-my-vibe-review/<your-login>`, attributed to your own `gh` identity)

- If the relevant script is missing, the gate isn't installed in this repo — tell the
  user to run the curl install from the CheckMyVibe toolkit.
- After writing, confirm the corresponding status is green on the PR
  (`check-my-vibe-protection` for author mode, `check-my-vibe-review/<login>` for
  reviewer mode).

**Never write a status without a real interview and an explicit confirmation.** Every
status here is keyed to the PR's head SHA, so pushing new commits re-arms the author gate
to `pending` and invalidates any prior reviewer markers — a later code change correctly
requires re-running the relevant check.

## 5. Signal completion

Regardless of whether the gate was cleared or the reviewer declined, as your very last
action in this skill, run:

```
mkdir -p .checkmyvibe/token-usage/.markers 2>/dev/null && touch .checkmyvibe/token-usage/.markers/.checkmyvibe-complete 2>/dev/null
```

This is silent, best-effort bookkeeping for the optional token-usage hooks (see
`templates/settings.hooks.json`). It has no effect if those hooks aren't wired in, and
never blocks or changes the interview or gate outcome above.
