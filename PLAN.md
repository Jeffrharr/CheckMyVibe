# Plan: PR CheckMyVibe Gate

A reusable toolkit that makes you (or any engineer) demonstrate understanding of a
PR **before it can merge** — via a private, local Claude Code interview, gated by a
required GitHub status check. Designed to be **hooked into other repos**, not used
only here.

Working name: **PR CheckMyVibe Gate**. The load-bearing identifier is the status
check context string `check-my-vibe-protection` (this is what branch protection keys on
and must match everywhere).

---

## Core idea

A GitHub Action **cannot** push an interactive chat onto your laptop — cloud runners
have no channel into a local terminal. So we invert the arrow:

1. **The Action arms a gate.** On every PR push it sets a commit status
   `check-my-vibe-protection = pending` on the head SHA. Branch protection lists this as a
   *required status check*, so the PR cannot merge while it is pending/missing.
2. **The local interview clears it.** You run a Claude Code slash command that pulls
   the PR diff, interviews you privately about the change, and — once you've
   demonstrated understanding — flips the same status to `success` on that exact SHA.
3. **New commits re-arm it.** Statuses are per-SHA, so pushing after you've cleared the
   gate resets it to pending and you re-confirm. This is desired: the understanding
   check tracks the *current* code, not a stale version.

Nothing about the Q&A touches GitHub — no comments, no public logs. The only thing that
goes to GitHub is a one-line status flip.

```
develop in Claude Code
        │
        ▼
/check-my-vibe  ──►  Claude interviews you (local, private)
        │                          │
        │                  "understanding confirmed"
        │                          ▼
        │            scripts/set-status.sh success  (gh api statuses/<head-sha>)
        ▼                          │
 Action arms pending  ─►  required status check ─►  merge unblocked
 on each push (CI)                 ▲
                                   │
                  pushing new commits re-arms pending
```

---

## Why not a git hook?

- **pre-commit** is the wrong granularity — you commit constantly; the check belongs at
  merge time, once per PR (re-armed per push).
- **git hooks have no good TTY** for an interactive chat, and are easy to bypass.
- A **slash command you invoke when ready** is explicit, runs inside your existing
  Claude Code session/login, and maps cleanly to "I'm about to merge this PR."

---

## Components

### A. Status writer (shared core)
`scripts/set-status.sh <pending|success> [--sha <sha>] [--pr <num>] [--repo owner/name]`
- Thin wrapper over `gh api repos/{owner}/{repo}/statuses/{sha}` with
  `context=check-my-vibe-protection`.
- The **pending** status carries an explicit, instructional `description`
  (e.g. `Run /check-my-vibe in Claude Code to unblock this PR`) and a
  `target_url` linking to the unblock docs — so the unblock path is visible right on the
  check, not buried. See "Making the unblock path obvious" below.
- **Single source of truth** used by both the CI Action and the local clear path, so the
  context string, description, and target_url never drift.
- Resolves head SHA from the PR when not passed (`gh pr view --json headRefOid`).

### B. The gate (GitHub side)
- A **vendored workflow** (`templates/checkmyvibe-gate.yml`) copied into each consumer's
  `.github/workflows/` by `install-into.sh`. Self-contained — no cross-repo access needed,
  which matters for private repos. Triggers on `pull_request: [opened, synchronize, reopened]`.
- Arms `check-my-vibe-protection = pending` on the head SHA by calling the vendored
  `.checkmyvibe/set-status.sh`.
- Needs `permissions: statuses: write`; uses the default `GITHUB_TOKEN`.
- Consumer adds `check-my-vibe-protection` to **branch protection → required status checks**.

### C. The interview (Claude Code side)
- A **Claude Code skill** exposing `/check-my-vibe [PR#]`.
- Flow: resolve PR (current branch or arg) → fetch `gh pr diff` + metadata → conduct an
  interactive interview (what changed, why, blast radius / affected modules, edge cases,
  tests, rollback) → keep probing until satisfied → ask for explicit confirmation →
  call `set-status.sh success`.
- Optional: write a short local, gitignored transcript/summary for your own notes.

### D. Install into other repos
- Docs + a helper (`scripts/install-into.sh <path-to-repo>`) that:
  1. drops the consumer gate workflow into the target's `.github/workflows/`,
  2. installs the skill (per-repo `.claude/skills/` or user-global `~/.claude/skills/`),
  3. prints the branch-protection step (can't fully automate without admin API + token).

---

## Making the unblock path obvious

A required check that blocks merge without telling you how to clear it is just a confusing
red X. The instruction "run `/check-my-vibe`" must be discoverable **from GitHub
itself**, where the engineer hits the wall — without leaking any of the private Q&A.

- **Status `description` (primary):** the pending status spells out the action verbatim,
  e.g. `Run /check-my-vibe in Claude Code to unblock this PR`. This text shows inline
  next to the check on the PR's merge box and checks tab.
- **Status `target_url` (the "Details" link):** points to an unblock guide (a section of
  this repo's README, or a short docs page) covering: install the skill, run
  `/check-my-vibe`, what to expect. One click from the failing check to the how-to.
- **Consumer README/CONTRIBUTING note:** the `install-into.sh` flow adds a short blurb to
  the target repo documenting the gate and the `/check-my-vibe` unblock step.
- **Optional generic PR comment:** a single, *non-personal* first-touch comment on PR open
  ("This repo requires an understanding check — run `/check-my-vibe` locally before
  merging"). Instructions only, never the engineer's answers. Off by default to keep PRs
  quiet; opt-in for teams that want maximum discoverability. The status description +
  target_url are the default, noise-free path.

All unblock copy lives in one place (the status writer) so it stays consistent across the
check, the docs link, and any optional comment.

---

## Planned repo layout (not built yet)

```
.
├── README.md                       # what it is + install into other repos
├── PLAN.md                         # this file
├── LICENSE                         # TBD
├── .gitignore
├── scripts/
│   ├── set-status.sh               # shared gh status writer (vendored into consumers)
│   └── install-into.sh             # vendor writer + workflow + skill into a target repo
├── templates/
│   └── checkmyvibe-gate.yml      # workflow copied into a consumer's .github/workflows/
└── skills/check-my-vibe/
    └── SKILL.md                    # the /check-my-vibe interview logic
```

---

## Auth & permissions

- **Arming (CI):** default `GITHUB_TOKEN` with `statuses: write`.
- **Clearing (local):** the developer's own `gh` auth. The status is attributed to that user.
- **Enforcement:** `check-my-vibe-protection` as a required status check in branch protection.
  (Repo admins can still bypass protection — acceptable for a personal tool; revisit for teams.)

---

## Open decisions

1. ~~**Project name**~~ — **resolved: `CheckMyVibe`.** Context string `check-my-vibe-protection` stays fixed.
2. ~~**Gate packaging**~~ — **resolved: vendoring.** `install-into.sh` copies a self-contained
   workflow + `set-status.sh` into each consumer (no cross-repo access friction, works for
   private repos). A `workflow_call` distribution is a possible future addition.
3. ~~**Skill install scope**~~ — **resolved: per-repo by default, `--global-skill` for `~/.claude/skills`.**
4. ~~**"Done" detection**~~ — **resolved: Claude judges completeness, then explicit y/n confirm**
   before flipping the status. No hard rubric yet (candidate for M4).
5. ~~**License**~~ — **resolved: MIT** (see `LICENSE`).

---

## Milestones

- **M0 — Plan & Repo:** git init + this plan. ✅
- **M1 — Status Writer & Gate:** `scripts/set-status.sh` + `templates/checkmyvibe-gate.yml`
  (pending-on-push) + branch-protection docs. ✅
- **M2 — The Interview:** `skills/check-my-vibe/SKILL.md` (interview + clear). ✅
- **M3 — Install Flow:** `scripts/install-into.sh` (vendors writer + workflow + skill) + README docs. ✅
- **M4 — Polish (optional):** transcript summaries, PR-author verification, configurable depth,
  richer status `target_url`. ⬜
  - Dogfood the gate on this repo: enforcement live on `main` — required `check-my-vibe-protection`
    status, `enforce_admins: false` (admin bypass kept on), no required-PR rule. Repo made
    public because free-tier branch protection requires it; the interview stays local either way. ✅
  - MIT license. ✅
  - Configurable skill name / check context / docs URL via `.checkmyvibe/config`
    (env overrides). ✅
