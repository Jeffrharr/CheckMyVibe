---
name: check-my-vibe
description: Walk through a pull request with the engineer to confirm they understand the change, then clear the relevant merge gate. Auto-routes based on who's invoking it and what they're asking for — PR author, reviewer doing a pre-review briefing, or reviewer doing a post-review debrief.
---

<!--
  Ships with the CheckMyVibe toolkit. The installer OVERWRITES the installed copy of this
  skill on every update, so edits here won't survive. Don't customize any interview by
  editing this orchestrator — create your own interview skill and point the relevant
  CHECKMYVIBE_* config variable (in .checkmyvibe/config) at it. The installer never
  touches a skill it didn't install.
-->

# Check My Vibe

You are helping someone get a pull request across the finish line — either as the author
finishing their own PR, or as a reviewer working through someone else's. You resolve the
PR, figure out which of those roles applies (and, for reviewers, whether they want a
pre-review briefing or a post-review debrief), hand off to the matching interview skill,
and — once it reports back and the person confirms — clear the matching gate.

This is private and local. Do not post anything to GitHub except the final status write.

## 1. Identify the PR and the role

- If the user passed a PR number, use it. Otherwise resolve the PR for the current branch:
  `gh pr view --json number,title,url,headRefOid,baseRefName,author,body`
- If there is no open PR, stop and tell the user to open one first — every gate here keys
  on the PR's head commit, so there is nothing to clear without a PR.
- Determine who's invoking: `gh api user --jq .login`.
- Compare that login (case-insensitive) against the PR's author (`.author.login`) to
  decide the mode:
  - **Author mode** — invoker is the PR's author.
  - **Reviewer mode** — invoker is not the author.

Within reviewer mode, decide **briefing vs. debrief** from what the user actually asked
for, not just role:

- If they asked to prep, get context, or "pre-review" this PR (i.e. before doing the real
  review) → **reviewer-briefing mode**.
- Otherwise (they're wrapping up a review they've already done, e.g. just ran `/review`
  or `/code-review`) → **reviewer-debrief mode**.

If the role is ambiguous (e.g. `gh api user` fails, or intent isn't clear), ask the user
directly which mode they want rather than guessing.

## 2. Run the matching interview

Each mode hands off to a separate, replaceable skill — kept swappable so a team can
customize any of these without touching gate logic here. Config lives in
`.checkmyvibe/config` (or the environment); `CHECKMYVIBE_CONFIG` overrides its path.

| Mode | Config variable | Default skill | Gate on success |
|---|---|---|---|
| Author | `CHECKMYVIBE_INTERVIEWER` | `pr-interview` | `check-my-vibe-protection` (author gate) |
| Reviewer briefing | `CHECKMYVIBE_REVIEWER_BRIEFING` | `reviewer-briefing` | none — informational only |
| Reviewer debrief | `CHECKMYVIBE_REVIEWER_DEBRIEF` | `reviewer-debrief` | `check-my-vibe-review/<login>` (per-reviewer marker) |

Read the relevant variable, e.g.:
`cat .checkmyvibe/config 2>/dev/null | grep CHECKMYVIBE_INTERVIEWER`

Invoke that skill, passing the PR number, and let it run to completion:

- **Author / reviewer-debrief modes** report back a short assessment and a judgment —
  **understood** / **not yet** (author) or **reviewed** / **not yet** (reviewer debrief).
  Carry that into the next step.
- **Reviewer-briefing mode** reports back a context brief (concepts, blast radius, open
  questions) with no judgment to act on — skip straight to step 5, there's no gate here.

If the configured skill isn't available, tell the user how to install it, then fall back
to interviewing them yourself, covering at least: what & why, blast radius, edge cases &
failure modes, testing, and rollback / risk (add: for reviewer-debrief mode, do this
skeptically — push back on thin justifications rather than just helping find answers).

## 3. Reviewer-briefing mode: stop here

If you ran reviewer-briefing, hand back its brief to the user and stop. There is no gate
to clear and no confirmation to ask for — this mode is purely prep for the review that's
about to happen.

## 4. Decide (author and reviewer-debrief modes only)

When the interview is done:

- Give a short, specific summary of what you heard — what's known, what the risks are,
  and any open questions the interview surfaced.
- If a genuinely load-bearing question is unresolved, say what it is and offer to keep
  going. Don't block on trivia; do block on things that could cause a real incident.
- Ask for explicit confirmation, phrased for the mode:
  - Author: **"Ready to mark this PR as understood and unblock merge? (yes/no)"**
  - Reviewer debrief: **"Ready to mark yourself as having reviewed and understood this
    PR? (yes/no)"**

## 5. Clear the gate

On an explicit "yes", flip the matching check via the vendored writer:

- Author mode:
  ```
  .checkmyvibe/set-status.sh success --pr <num>
  ```
- Reviewer-debrief mode:
  ```
  .checkmyvibe/set-review-status.sh success --pr <num>
  ```

- If the relevant script is missing, the gate isn't installed in this repo — tell the
  user to run the curl install from the CheckMyVibe toolkit.
- After writing, confirm the corresponding status is green on the PR
  (`check-my-vibe-protection` for author mode, `check-my-vibe-review/<login>` for
  reviewer-debrief mode).

**Never write a status without a real interview and an explicit confirmation.** Every
status here is keyed to the PR's head SHA, so pushing new commits re-arms the author gate
to `pending` and invalidates any prior reviewer markers — a later code change correctly
requires re-running the relevant check.
