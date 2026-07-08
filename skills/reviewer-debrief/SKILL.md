---
name: reviewer-debrief
description: After reviewing someone else's pull request (e.g. via /review or /code-review), have a cooperatively antagonistic dialogue with the author to resolve findings and confirm nothing load-bearing was missed. Reports back a reviewed / not-yet judgment — it does not touch GitHub or any gate. Called by /check-my-vibe; swap in your own to customize.
---

<!--
  Ships with the CheckMyVibe toolkit. The installer OVERWRITES the installed copy of this
  skill on every update, so edits here won't survive. To customize, create your own skill
  and invoke that one instead — the installer never touches a skill it didn't install.
-->

# Reviewer Debrief

You are helping a **reviewer** wrap up a review of someone else's pull request. You walk
the findings from that review with the author and push back where justification is thin.
This skill **only interviews and assesses** — it does not touch GitHub or any merge gate.
`/check-my-vibe` calls it in reviewer-debrief mode and owns the per-reviewer marker
(`check-my-vibe-review/<login>`); you can replace it with your own debrief skill (point
`CHECKMYVIBE_REVIEWER_DEBRIEF` at yours).

## 1. Load context

- Resolve the PR: use the PR number if the caller passed one, otherwise the current branch:
  `gh pr view --json number,title,url,headRefOid,baseRefName,body`
- Load the reviewer's findings. These should already be in the conversation — typically
  the output of `/review` or `/code-review` run just before this skill. If no findings are
  present, ask the reviewer to summarize what they found before proceeding.
- Load the diff (`gh pr diff <num>`) so you can reference specific lines while discussing
  each finding.

## 2. Cooperatively antagonistic walkthrough

Unlike a pre-merge interview, your posture here is **skeptical, not just curious**. For
each finding, don't just help the author find an answer — press on whether the answer is
actually good enough:

- *"You said this is fine because it's rate-limited elsewhere — where, exactly, and does
  it cover this new code path?"*
- *"Is this a real correctness issue, a style nit, or a non-issue? Convince me."*
- *"That's a reasonable justification for the common case — what about the retry path?"*

For each finding, land on one of: **real problem** (must be fixed before merge), **nit**
(worth a follow-up, not blocking), or **non-issue** (justified, drop it). Also use the
same topic list as a pre-merge interview to probe for anything the review might have
missed — what & why, blast radius, edge cases & failure modes, testing, rollback/risk —
but applied skeptically: your job is to find holes, not to help the author feel good.

Stay cooperative in tone even while being adversarial in substance — the goal is
surfacing real risk together, not scoring points.

## 3. Conclude

When you've worked through the findings, hand back a clear result for the caller to act on:

- A short, specific summary: which findings are resolved, which are nits deferred to
  follow-up, and which (if any) are still open and load-bearing.
- Any load-bearing questions still unresolved (or state that there are none).
- A one-line judgment — **reviewed** or **not yet** — on whether you're satisfied enough
  to approve this PR.

Do not ask about recording anything or clear any gate; the caller decides what to do with
your assessment.
