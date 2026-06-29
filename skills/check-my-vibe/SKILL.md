---
name: check-my-vibe
description: Walk through an open pull request with the engineer to make sure they understand the change and how it affects the codebase, then clear the `check-my-vibe-protection` merge gate. Use right before merging a PR.
---

<!--
  Ships with the CheckMyVibe toolkit. The installer OVERWRITES the installed copy of this
  skill on every update, so edits here won't survive. Don't customize the interview by
  editing this orchestrator — create your own interview skill and point CHECKMYVIBE_INTERVIEWER
  (in .checkmyvibe/config) at it. The installer never touches a skill it didn't install.
-->

# Check My Vibe

You are helping an engineer get their pull request across the finish line. You resolve the
PR, hand off to an interview skill that confirms they understand the change, and — once they
confirm — clear the required GitHub status check (`check-my-vibe-protection`) that unblocks
the merge.

This is private and local. Do not post anything to GitHub except the final status flip.

## 1. Identify the PR

- If the user passed a PR number, use it. Otherwise resolve the PR for the current branch:
  `gh pr view --json number,title,url,headRefOid,baseRefName,body`
- If there is no open PR, stop and tell the user to open one first — the gate keys on the
  PR's head commit, so there is nothing to clear without a PR.

## 2. Run the interview

The interview itself lives in a separate, replaceable skill — keeping it swappable so a team
can customize how engineers are questioned without touching the gate logic here. Pick which
one to run:

- Default: **`pr-interview`**.
- Override: if `.checkmyvibe/config` (or the environment) sets `CHECKMYVIBE_INTERVIEWER`,
  use that skill name instead:
  `cat .checkmyvibe/config 2>/dev/null | grep CHECKMYVIBE_INTERVIEWER`

Invoke that skill, passing the PR number, and let it run to completion. It loads the diff,
interviews the engineer, and reports back a short assessment of whether they understand the
change. Carry that assessment into the next step.

If the configured interview skill isn't available, tell the user how to install it, then
fall back to interviewing them yourself — cover at least: what & why, blast radius, edge
cases & failure modes, testing, and rollback / risk.

## 3. Decide

When the interview is done:

- Give a short, specific summary of what you heard — what they know, what the risks are,
  and any open questions the interview surfaced.
- If a genuinely load-bearing question is unresolved, say what it is and offer to keep
  going. Don't block on trivia; do block on things that could cause a real incident.
- Ask for explicit confirmation: **"Ready to mark this PR as understood and unblock merge? (yes/no)"**

## 4. Clear the gate

On an explicit "yes", flip the check to success via the vendored writer:

```
.checkmyvibe/set-status.sh success --pr <num>
```

- If `.checkmyvibe/set-status.sh` is missing, the gate isn't installed in this repo —
  tell the user to run the curl install from the CheckMyVibe toolkit.
- After flipping, confirm the `check-my-vibe-protection` status is green on the PR.

**Never set `success` without a real interview and an explicit confirmation.** Pushing new
commits re-arms the gate to `pending`, so a later code change correctly requires re-running
this check.
