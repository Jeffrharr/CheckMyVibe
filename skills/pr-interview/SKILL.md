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

Obvious bugs are the least interesting thing to find — a plausible-sounding explanation is more
dangerous than a bug, because it hides a conceptual hole instead of admitting one. Favor questions
in these veins, which target that gap directly:

- **Invariant, not mechanism** — ask what guarantee the change preserves, then construct a sequence
  of events where that guarantee breaks even though every individual step succeeds. ("You said this
  can't cause duplicate processing — what would have to be false for it to happen anyway?")
- **Simplicity justification** — what's the simplest implementation that would also pass the tests,
  and why is the actual approach justified over it? Catches overengineering that's easy to defend
  after the fact but wasn't the obvious path.
- **Test-kill** — for any added test, what's the smallest implementation change that breaks
  correctness while keeping the test green? If the answer is "not much," the test isn't proving
  what it looks like it's proving.
- **Plain-language before/after** — ask the engineer to describe the behavioral difference with zero
  implementation words ("users could see stale permissions for 15 minutes, now it's immediate" —
  not "I added a flag and changed the handler"). If they can't do this without naming a function or
  variable, they may understand the mechanism without understanding its effect.
- **Confidence inversion** — ask what part of the change they're least sure about, then ask why that
  uncertainty isn't a reason to block. People defend their strengths by default; this surfaces blind
  spots they wouldn't have volunteered.

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
check with the engineer explicitly before advancing.

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

**When an answer is solid**, say so and ask the engineer if they'd like to move on. Don't re-litigate settled ground.

If something genuinely load-bearing remains unresolved after you've explored it together,
name it: *"I'm not sure we've got a handle on X yet — want to dig into that before we
clear this?"*

The engineer may source new issues. Critical issues should be considered an additional question and
investigated.

Before moving on from a question, ask the engineer if they would like to continue to the next question. They should be able to start a conversation to validate any other information.

## Changes and comments
The discussion may prompt the engineer to make changes. If this is a colleague's PR,
suggest leaving a GitHub comment on the relevant line, using either the engineer's
**exact wording** or an AI summary — ask which they want, don't assume.

If this PR is the user's OWN PR, prefer to make local changes and provide them with the diff before pushing.

## Github review comment format
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

When you've covered the ground that matters for this change, hand back a **confidence
profile**, not a pass/fail — a green check invites complacency, a map of what's solid and
what's shaky invites the right amount of scrutiny:

```
Understanding: 95%

Strong:
✓ Data flow
✓ Failure handling
✓ API changes

Weak:
⚠ Why this retry policy is safe
⚠ Backpressure behavior

Recommendation: Human review required
```

- **Understanding %** is your holistic estimate across everything discussed, not a formula —
  weight CRITICAL/IMPORTANT topics heavily; a single unresolved CRITICAL question should cap
  this well below 70% regardless of how many USEFUL topics went well.
- **Strong** — topics where the engineer's answer was solid enough that you moved on without
  reservation.
- **Weak** — topics where the answer was thin, uncertain, or still open. Every CRITICAL or
  IMPORTANT question that didn't fully resolve belongs here, named specifically (not "some
  edge cases" — the actual gap: *"why this retry policy is safe"*, not *"retries"*).
- **Recommendation** — one line, in your own words, e.g. *"Clear to merge"*, *"Human review
  required"*, or *"Needs another pass on X before merge"*. This is what the caller acts on;
  don't soften it to spare feelings.

Do not ask about merging or clear any gate; the caller decides what to do with your
assessment.

## Review metrics

Alongside the confidence profile, report three blocks. These are estimates from your own
read of the conversation, not a formula — state judgment calls in one line rather than
over-formalizing.

**Review coverage** — how much of the diff you actually engaged with, broken down (not one
blended percentage, since "explained" and "touched" mean different things):

```
Review coverage:
  Changed lines analyzed: 92%
  Control flow paths explored: 71%
  New functions explained: 100%
  External dependencies understood: 40%

Skipped:
  - generated protobuf bindings (expected)
  - vendored library changes (expected)
  - retry logic in FooClient: insufficient context on service guarantees
```

- *Changed lines analyzed* — of the diff's substantive lines (skip pure boilerplate: imports,
  docstrings, `__init__` bodies with no branching), how many did a question actually touch.
- *Control flow paths explored* — of the distinct branches/error paths the diff introduces or
  changes, how many did you actually trace (not just the happy path).
- *New functions explained* — of new functions/methods, how many were understood well enough
  to describe in plain language.
- *External dependencies understood* — of external systems the diff touches (DB, queue, HTTP
  client, cache, etc.), how many failure modes you actually discussed for that dependency vs.
  assumed benign.
- **Skipped** — name what you didn't cover and say why. Tag it `(expected)` when it's
  boilerplate/generated/vendored code with nothing to interview about; otherwise state the
  real reason (no time, no context, engineer didn't know) so a low number here isn't confused
  with the boilerplate case.

**Review robustness** — how much the interview actually tested its own conclusions, not just
recorded them:

```
Review robustness:
  Initial objections raised: 3
  Objections resolved with evidence: 3
  Reviewer changed position: 1
  Unsupported assumptions remaining: 0
```

- *Initial objections raised* — count of CRITICAL/IMPORTANT concerns you opened with.
- *Objections resolved with evidence* — of those, how many were closed by actual evidence
  (code shown, a trace, a config checked) rather than the engineer's assurance alone.
- *Reviewer changed position* — count of times *you* revised your own read of the risk after
  seeing evidence, as opposed to the engineer changing theirs. Zero here across many sessions
  is itself a signal the interview isn't engaging with pushback.
- *Unsupported assumptions remaining* — of the concerns above, how many are still resting on
  "trust me" rather than something you verified. Should be reflected in **Weak** in the
  confidence profile above, not just here.

Also note, separately, whether the interview changed the *engineer's* mind about anything — a
fix made, an assumption corrected, a design reconsidered — as opposed to just confirming what
they already believed. A review that only finds bugs is weaker than one that changes a belief.

### Logging the metrics

Read `CHECKMYVIBE_COVERAGE_LOG` from `.checkmyvibe/config` (or the environment;
`CHECKMYVIBE_CONFIG` overrides the config path, same as elsewhere in this
toolkit): `cat .checkmyvibe/config 2>/dev/null | grep CHECKMYVIBE_COVERAGE_LOG`.

If it's set, append one line to that path (create the file and any parent directory if
missing) as a JSON object capturing the confidence profile and both metric blocks above:

```json
{"date": "2026-07-08", "pr": 18, "branch": "demo/dummy-domain-model", "understanding_pct": 95, "recommendation": "human review required", "coverage": {"changed_lines_pct": 92, "control_flow_pct": 71, "functions_explained_pct": 100, "dependencies_understood_pct": 40}, "skipped": [{"item": "generated protobuf bindings", "expected": true}, {"item": "retry logic in FooClient", "expected": false, "reason": "insufficient context on service guarantees"}], "robustness": {"objections_raised": 3, "objections_resolved": 3, "reviewer_changed_position": 1, "unsupported_assumptions_remaining": 0}, "mind_changed": true}
```

If the variable is unset, skip logging entirely — don't create the file. This is opt-in, not
a default-on side effect.

Entries must match `templates/coverage-log.schema.json`. After appending, check for an
interpreter first — `command -v python3` — since this is the toolkit's only Python
dependency and can't be assumed present everywhere bash and `gh` are. If found, validate
the line with `scripts/validate-coverage-log.py <path>` (stdlib-only, no install required
— it uses `jsonschema` for full validation if present, otherwise a built-in structural
check) and fix the entry before finishing if it reports a problem. If `python3` isn't
found, skip validation and say so in the summary — don't treat a missing interpreter as a
validation failure.
