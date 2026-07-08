---
name: pr-interview
description: Conduct a private, conversational pre-merge PR interview with the engineer to confirm they understand the change and its blast radius. Reports back a short understanding assessment.
---

<!--
  Ships with the CheckMyVibe toolkit. The installer OVERWRITES the installed copy of this
  skill on every update, so edits here won't survive. To customize the pre-merge interview,
  create your own skill and point CHECKMYVIBE_INTERVIEWER (in .checkmyvibe/config) at it —
  the installer never touches a skill it didn't install, so your version is preserved.
-->

# PR Interview

Walk an engineer through a pull request until AI and the engineer understand the change. This skill
**only interviews and assesses** and reports to '/check-my-vibe' regarding success or failure. The tone should always feel collaberative.

## First load the change

- Resolve the PR: use the PR number if the caller passed one, otherwise the current branch:
  `gh pr view --json number,title,url,headRefOid,baseRefName,body`
- Diff and file list: `gh pr diff <num>` and `gh pr diff <num> --name-only`.
- Read the PR title/body for the stated intent.
- Read surrounding code in the repo as needed to understand blast radius — don't reason
  from the diff alone.
- Read any summary already given by an AI reviewer and any comments by previous reviewers.

## Conversational interview

Before opening the conversation, read the diff carefully and prepare **2–6 questions**
depending on the scope and risk of the change. Prioritize **architectural effects** — how
this change affects the system's structure, interfaces, and dependencies. If there's a
critical or non-obvious code change, investigate that. Not generic — questions should
be tied to specific lines, functions, patterns, or design decisions in this diff. Questions should 
be antagonistic, but tone remains collaberative and conversational. Decide how important each question
is and rank them CRITICAL | IMPORTANT | USEFUL | ENGINEER-QUESTION and use the critera above to determine why.
Note that ENGINEER-QUESTION is for things that you're uncertain about and want the engineer to check for you

Examples of the right shape:

- *"'Specific Change' moves auth out of the middleware layer — what's now responsible for enforcing it
  on routes that don't go through the new handler?"*
- *"This PR is writing to the cache before the DB commit succeeds — How do we handle writes that fail halfway through."*
- *"This PR adds a new required config key. What happens on startup if it's missing?"*

Before asking questions, open with a short summary of the PR, then present the questions
for the engineer to pick from — don't just ask the first one. Assume they may not have
looked at the diff themselves and never intend to (describe each in plain behavioral
terms, not by quoting code — that's what step-by-step follow-ups are for once they've
picked one). Number them in priority order and tag each with how load-bearing it is:

```
1. **Headline** — CRITICAL | IMPORTANT | USEFUL | ENGINEER-QUESTION
   Plain-language description of the issue and the open question, phrased so someone
   who's never seen this diff can follow it.
```

Rank by the same priority rule as above: architectural effects first, then critical or
non-obvious behavior. **Wrap the numbered list itself in a fenced code block when you
present it** — plain markdown collapses the line breaks between items, so without the
fence they run together as a wall of text.

Example:
```
1. **Partial Batch Failure** — CRITICAL
This script sends notifications for a list of IDs, one after another, retrying each one that fails. If one of them fails completely — every retry used up — does the script give up on the whole batch, or keep going and try the rest?


2. **Permanent vs. Temporary Failures** — IMPORTANT
Right now, a notification that fails is treated the same whether it's something that will never succeed (a bad ID, a malformed request) or something temporary (a timeout, a server hiccup). Is that acceptable, or should a permanent failure be handled differently from a temporary one?


3. **Untrusted ID Values** — USEFUL
Each notification is identified by an ID, and that ID gets used to build a filename for tracking whether it's already been sent. Do you know where these IDs actually come from — and whether they're guaranteed to be simple, safe values, or could one contain something unusual that would matter for building that filename safely?
```

## Question Introduction

Open the question with a structured breakdown before turning it into a
back-and-forth: Give a verbatim code snippet (per the anchoring rule below), summarize what it does and why in plain english.

Then explain why you gave it the priority level for each relevent category you evaluated. In the following example, you decided that this question is central to the PR and has a wide blast radius.
Use 1-5 core categories without restating any information. If you use only 1 category, it must be extremely critical.

EXAMPLE:
```sh
**CORE LOGIC**:
The primary business logic of the PR is inside this switch case.

**BLAST RADIUS**:
This interacts with CriticalClass and could affect DB reads, potentially blocking them.
"
```

Then restate the posed question and begin a conversation.

Don't move on to the next question while the current one's open question is still
unresolved — especially at CRITICAL/IMPORTANT priority. A code fix elsewhere (e.g. one
suggestion applied) doesn't resolve it unless it actually answers the open question;
check with the engineer explicitly before advancing. Phrase that check as an inviting
follow-up question rather than a blocking statement — e.g. *"Before we move to Question
3 — do you already know X, or is that something we'd want to check together first?"* —
so it reads as curious collaboration, not gatekeeping.

## Anchor the conversation in the real text / code.
When you reference a change, or the engineer asks to see one, paste the actual snippet
before you comment on it, with each line numbered so you can point back at a specific one —
instead of your summary of it, since a paraphrase can drift from what the diff actually
says, and the engineer should be reacting to their own code, not your account of it.

Example:

`scripts/fake-scratch-feature.sh:27-36`
```sh
27  send_notification() {
28    local id="$1"
29    local url="$2"
30
31    # mark as sent before we know the request actually succeeded
32    touch "$STATE_DIR/$id.sent"
33
34    retry_with_backoff curl -fsS -X POST "$url" -d "{\"id\":\"$id\"}"
35  }
```

Keep the language tag on the fence (e.g. ```sh) alongside the line numbers — that's what
gives the snippet syntax coloring; dropping it to fit numbers in loses the highlighting for
no reason.

## Tone and wording
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
the answer. Continue the conversation until the engineer can thouroughly explain the change.

**When an answer is solid**, say so and move on. Don't re-litigate settled ground.

If something genuinely load-bearing remains unresolved after you've explored it together,
name it: *"I'm not sure we've got a handle on X yet — want to dig into that before we
clear this?"*

The engineer may source new issues. Critical issues should be considered an additional question and
investigated.

## Changes and comments
The discussion may prompt the engineer to make changes. If this is a colleague's PR,
suggest leaving a GitHub comment on the relevant line, using either the engineer's
**exact wording** or an AI summary — ask which they want, don't assume.

Post it as a **review comment anchored to that diff line**, not a general PR comment —
that's what makes it appear inline against the code instead of at the bottom of the PR.
If the comment includes a code change, use GitHub's suggestion syntax so the author can
apply it with one click:

```
​```suggestion
<replacement line(s)>
​```
```

Leave the review in **`PENDING`** state — don't submit it — so nothing is visible on the
PR until the engineer reviews and submits it themselves. `gh pr comment` cannot do either
of these (no line anchor, no pending state); use `gh api` against the pulls review-comment
endpoints instead.

## 3. Conclude

If this conversation left any review comments pending (per the section above), ask the
engineer whether to submit that review now, and which event to submit it as (`COMMENT`,
`APPROVE`, or `REQUEST_CHANGES`) — don't submit it without asking, since a pending review
is invisible to everyone else until it is.

When you've covered the ground that matters for this change, hand back a clear result for
the caller to act on:

- A short, specific summary of what the engineer demonstrated they understand.
- Any load-bearing questions still unresolved (or state that there are none).
- A one-line judgment — **understood** or **not yet** — on whether they understand the
  change well enough to own it in production.

Do not ask about merging or clear any gate; the caller decides what to do with your
assessment.
