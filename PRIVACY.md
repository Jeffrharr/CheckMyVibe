# Privacy Policy

CheckMyVibe is a set of Claude Code skills and an optional GitHub Action. This
document covers what the toolkit itself does with data — not Claude Code, the
Anthropic API, or GitHub, each of which has its own privacy policy governing
how it handles your data.

## What this toolkit does

- **The interview is local.** `/check-my-vibe` and `/pr-interview` run entirely
  inside your own Claude Code session. The conversation is never sent to
  CheckMyVibe, posted to GitHub, or transmitted to any third party by this
  toolkit.
- **The only network write is a commit status.** On explicit confirmation, the
  skill flips a GitHub status check (`check-my-vibe-protection` or
  `check-my-vibe-review/<login>`) on the current PR. That status carries no
  interview content — just a state (`pending`/`success`) and a link back to
  this repo's README.
- **The optional coverage log stays local.** If `CHECKMYVIBE_COVERAGE_LOG` is
  set, a JSON summary of the interview (understanding %, which topics were
  discussed, a recommendation) is appended to a local file
  (`.checkmyvibe/coverage.jsonl` by default). This file is gitignored by the
  installer — it is never committed, pushed, or sent anywhere by the toolkit.
- **Token usage, if logged, is a local count, not your conversation.** When the
  optional token-usage hooks are wired in
  (`scripts/post-skill-mark-token-usage-start.sh` +
  `scripts/stop-log-token-usage.sh`), a `token_usage` field — input tokens,
  output tokens, and cache read/write tokens, split out per subagent — is
  added to the same local coverage-log line, plus a companion detail file
  under `.checkmyvibe/token-usage/`. These are **LLM token counts** (a measure
  of Anthropic API usage), unrelated to the GitHub auth tokens (e.g.
  `GH_TOKEN`) used elsewhere in this toolkit's `gh` calls. The hook reads
  numeric usage totals out of the session transcript Claude Code already
  stores locally (`~/.claude/projects/...`); it never reads or stores the
  transcript's actual conversation text, and nothing is transmitted anywhere.
- **No telemetry, analytics, or tracking.** The scripts, skills, and GitHub
  Action ship with no analytics SDK, no phone-home behavior, and no usage
  tracking of any kind.

## What this toolkit does not control

- **Claude Code / the Anthropic API.** Running `/check-my-vibe` or
  `/pr-interview` sends the PR diff and your conversation to Claude, subject
  to [Anthropic's Privacy Policy](https://www.anthropic.com/legal/privacy) and
  the terms of your Claude Code plan.
- **GitHub.** The gate's status writes, `gh` CLI calls, and the GitHub Action
  itself operate through GitHub's API and are subject to
  [GitHub's Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-privacy-statement).

## Data you control

Everything this toolkit writes locally — `.checkmyvibe/config`,
`.checkmyvibe/set-status.sh`, `.checkmyvibe/set-review-status.sh`, any
coverage log, or any token-usage detail file — lives on your own machine, is
gitignored by default, and can be deleted at any time with no effect other
than needing to reinstall or losing local interview history.

## Changes to this policy

If this toolkit ever adds a feature that changes any of the above (for
example, centralized logging or telemetry), this file will be updated in the
same PR that introduces it.
