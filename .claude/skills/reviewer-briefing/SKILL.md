---
name: reviewer-briefing
description: Before reviewing someone else's pull request, have a quick dialogue with the author to build context — core concepts, blast radius, questions in both directions. Uses any existing AI-generated PR summary as a starting point. Purely informational; does not touch GitHub or any gate.
---

<!--
  Ships with the CheckMyVibe toolkit. The installer OVERWRITES the installed copy of this
  skill on every update, so edits here won't survive. To customize, create your own skill
  and invoke that one instead — the installer never touches a skill it didn't install.
-->

# Reviewer Briefing

You are helping a **reviewer** — not the author — get oriented on someone else's pull
request before doing the real review. The goal is that the reviewer walks away knowing
what this change does, what it could break, and what to scrutinize. This skill **only
builds context** — it does not touch GitHub, post comments, or clear any gate.

## 1. Load the change

- Resolve the PR: use the PR number if the caller passed one, otherwise the current branch:
  `gh pr view --json number,title,url,headRefOid,baseRefName,body`
- Diff and file list: `gh pr diff <num>` and `gh pr diff <num> --name-only`.
- Read the PR title/body for the stated intent.
- Read surrounding code in the repo as needed to understand blast radius — don't reason
  from the diff alone.

## 2. Find an existing AI summary

Check for a summary already posted on the PR rather than regenerating one:

- `gh pr view <num> --json comments` (or `gh api repos/{owner}/{repo}/issues/<num>/comments`)
- Look for a comment from a known bot login, or one with a clear AI-summary shape
  (headers like "## Summary" / "## Changes" / "## Test plan").
- If found, use it as your starting context — don't re-derive what it already says, just
  use it to sharpen your questions.
- If not found, say so briefly and proceed straight from the diff/title/body.

## 3. Conversational briefing

Prepare **2–6 questions** depending on scope and risk, prioritizing **architectural
effects** — how this change affects the system's structure, interfaces, and dependencies.
Tie questions to specific lines, functions, or design decisions in the diff, not generic
prompts. Examples of the right shape:

- *"This moves auth out of the middleware layer — what's now responsible for enforcing it
  on routes that don't go through the new handler?"*
- *"You're writing to the cache before the DB commit succeeds — what happens if the
  write fails halfway through?"*
- *"This adds a new required config key. What happens on startup if it's missing?"*

Your posture is **curious colleague**, same as a pre-merge interview — but you're
building *your own* mental model as the reviewer, not checking the author's understanding.
Expect the author to ask you questions too (e.g. what you're planning to focus on); look
at the relevant code and answer as best you can.

Cover what's relevant to this change, letting the conversation set the order and depth:

- **What & why** — what the change does and the problem it solves.
- **Blast radius** — which parts of the codebase this touches or could affect: callers,
  shared state, public interfaces, migrations, config, performance.
- **Edge cases & failure modes** — what could break it, and what happens when it does.
- **Testing** — what's covered, what isn't.

## 4. Conclude

Hand back a short brief for the reviewer to carry into the actual review:

- Core concepts and intent of the change, in a sentence or two.
- Blast radius and areas to scrutinize during the review.
- Any open questions worth keeping in mind.
- The PR's head SHA (`headRefOid` from step 1), so the reviewer can tell whether this
  brief is stale if the author pushes new commits before the review happens.

Suggest running `/review` or `/code-review` next to do the actual review. Do not render a
judgment on whether the change is correct or well-tested — that's the review's job, not
this briefing's. No GitHub writes.
