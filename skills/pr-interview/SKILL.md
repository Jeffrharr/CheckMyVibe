---
name: pr-interview
description: Conduct a private, conversational pre-merge interview with the engineer about a pull request's diff to confirm they understand the change and its blast radius. Reports back a short understanding assessment — it does not touch GitHub or any merge gate. Called by /check-my-vibe; swap in your own to customize the interview.
---

<!--
  Ships with the CheckMyVibe toolkit. The installer OVERWRITES the installed copy of this
  skill on every update, so edits here won't survive. To customize the pre-merge interview,
  create your own skill and point CHECKMYVIBE_INTERVIEWER (in .checkmyvibe/config) at it —
  the installer never touches a skill it didn't install, so your version is preserved.
-->

# PR Interview

Walk an engineer through a pull request until both of you understand the change. This skill
**only interviews and assesses** — it does not touch GitHub or any merge gate. `/check-my-vibe`
calls it and owns the gate; you can replace it with your own interview skill (point
`CHECKMYVIBE_INTERVIEWER` at yours).

## 1. Load the change

- Resolve the PR: use the PR number if the caller passed one, otherwise the current branch:
  `gh pr view --json number,title,url,headRefOid,baseRefName,body`
- Diff and file list: `gh pr diff <num>` and `gh pr diff <num> --name-only`.
- Read the PR title/body for the stated intent.
- Read surrounding code in the repo as needed to understand blast radius — don't reason
  from the diff alone.

## 2. Conversational interview

Before opening the conversation, read the diff carefully and prepare **2–6 questions**
depending on the scope and risk of the change. Prioritize **architectural effects** — how
this change affects the system's structure, interfaces, and dependencies. If there's a
critical or non-obvious code change, investigate that too. Not generic — questions should
be tied to specific lines, functions, patterns, or design decisions in this diff. Examples
of the right shape:

- *"This moves auth out of the middleware layer — what's now responsible for enforcing it
  on routes that don't go through the new handler?"*
- *"You're writing to the cache before the DB commit succeeds — what happens if the
  write fails halfway through?"*
- *"This adds a new required config key. What happens on startup if it's missing?"*

Open with one of these questions, not a generic prompt. Let it be the start of a real
conversation.

Your posture is **curious colleague, not examiner**. You want to understand the change
alongside the engineer, not catch them out. The engineer may not fully know the codebase —
that's fine. **Expect them to ask you questions too.** When they do, look at the relevant
code and answer as best you can: *"Let me check what calls that..."* Read files, trace
callers, check configs — use the codebase to help them understand what they've built.
The goal is that both of you understand the change by the end.

Cover the topics below, but let the conversation determine the order and depth — not every
PR needs the same level of scrutiny on every dimension:

- **What & why** — what the change does and the problem it solves.
- **Blast radius** — which parts of the codebase this touches or could affect: callers,
  shared state, public interfaces, migrations, config, performance.
- **Edge cases & failure modes** — what inputs or conditions could break it; what happens
  when it fails.
- **Testing** — what's covered, what isn't, and why that gap is acceptable.
- **Rollback / risk** — how to undo it and the worst case if it's wrong.

**When an answer is thin or uncertain**, offer a pointer rather than pushing back:
*"Have you checked what calls this function?"* or look it up together. Help them find
the answer.

**When an answer is solid**, say so and move on. Don't re-litigate settled ground.

If something genuinely load-bearing remains unresolved after you've explored it together,
name it: *"I'm not sure we've got a handle on X yet — want to dig into that before we
clear this?"*

## 3. Conclude

When you've covered the ground that matters for this change, hand back a clear result for
the caller to act on:

- A short, specific summary of what the engineer demonstrated they understand.
- Any load-bearing questions still unresolved (or state that there are none).
- A one-line judgment — **understood** or **not yet** — on whether they understand the
  change well enough to own it in production.

Do not ask about merging or clear any gate; the caller decides what to do with your
assessment.
