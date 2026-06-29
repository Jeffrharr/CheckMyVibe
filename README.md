# About
check-my-vibe assists coders with understanding code changes that have been made by LLMs (currently Claude Code)
by initiating a dialogue between the LLM and the coder to facilitate mutual understanding of major code changes.

It's accompanied by a **github action** that can block PR merges until they have run `check-my-vibe`

This is a private dialogue between the software engineer and the LLM. We admit to ourselves that the process of
learning and understanding the inner workings of a PR can be messy and imperfect.

- **Private** — the Q&A happens locally in Claude Code. Nothing is posted to the PR or
  visible in CI logs; only a one-line status flip touches GitHub.
- **Optionally Enforced** — a GitHub Action arms an `check-my-vibe-protection` status as *pending* on every
  push; the PR cannot merge until your local interview flips it to *success*.

See [PLAN.md](./PLAN.md) for the full design and rationale.

## How it works

A GitHub Action can't push an interactive chat onto your laptop, so the arrow is inverted:
the local interview is what unblocks the PR.

1. Develop in claude code.
2. Push PR and review it sufficiently.
3. Run `/check-my-vibe` to further your understanding
4. Claude runs .checkmyvibe/set-status.sh success for your PR (there is a bit of an honor system)
5. PR is unblocked and you can merge.

----

Because the status is written per commit SHA, pushing new commits resets the gate to
`pending` — so the check always reflects the *current* code.

## Install into a repo

### Quick install

The skill `/check-my-vibe` is installed locally in the repo along with its associated `.checkmyvibe/set-status.sh` script.

```sh
curl -fsSL https://raw.githubusercontent.com/Jeffrharr/CheckMyVibe/main/scripts/global-install.sh | bash -s -- /path/to/target-repo
```

This downloads and installs everything without cloning CheckMyVibe:

- `/check-my-vibe` + `pr-interview` skills → `~/.claude/skills/` (global, work in any repo)
- `.checkmyvibe/set-status.sh` — vendored into the target repo (gitignored; local tooling)
- `.github/workflows/checkmyvibe-gate.yml` — vendored into the target repo (commit this)
- `.checkmyvibe/config` — config template, gitignored (skipped if one already exists)

The installer also adds `.checkmyvibe/` to the target repo's `.gitignore`. The vendored
`set-status.sh`/`config` are per-developer local tooling — CI arms the gate via the published
action, not these files — so each developer runs the installer rather than committing them.

To install just the skill without targeting a specific repo yet:

```sh
curl -fsSL https://raw.githubusercontent.com/Jeffrharr/CheckMyVibe/main/scripts/global-install.sh | bash
```

### Manual install (from a local clone)

If you have a local clone of this repo:

```sh
scripts/install-into.sh /path/to/target-repo            # skill lives in the target repo
```

### After either install

Then, in the target repo:

1. Commit the gate workflow (`.github/workflows/checkmyvibe-gate.yml`). The `.checkmyvibe/`
   tooling is gitignored — each developer runs the installer locally.
2. **Branch protection → Require status checks to pass →** add a required check named exactly
   `check-my-vibe-protection`. This is what actually blocks merges. (The workflow still arms the
   check and the `/check-my-vibe` flow still works without this step — but nothing is
   *enforced* until the check is required.)

> **Note:** Required status checks need branch protection, which on GitHub's free tier is
> only available for **public** repos (private repos need Pro/Team). Without it, the gate is
> advisory — the check shows on PRs but doesn't block merge.

## Usage

1. Open a PR. The gate posts `check-my-vibe-protection = pending` and the merge button is blocked.
2. When you're ready to merge, run `/check-my-vibe` in Claude Code. It pulls the diff
   and interviews you about the change.
3. Once you've shown you understand it and confirm, the skill flips the check to `success`
   and the PR can merge.

## Skills

The toolkit ships two Claude Code skills:

- **`check-my-vibe`** — the orchestrator wired into the gate. It resolves the PR, hands off
  to an interview skill, and on your explicit confirmation clears the gate. This is the one
  you run before merging.
- **`pr-interview`** — the conversational pre-merge interview engine that `check-my-vibe`
  calls. It loads the diff, walks you through the change, and reports back whether you
  understand it — it never touches the gate. **Replaceable:** point `CHECKMYVIBE_INTERVIEWER`
  at your own skill to customize how engineers are questioned, without changing the gate
  logic.

## Configuration

The gate reads optional settings from `.checkmyvibe/config` (created by the installer),
overridable by environment variables. Precedence: **built-in default < `.checkmyvibe/config` < env**.

| Setting | Default | Controls |
|---|---|---|
| `CHECKMYVIBE_SKILL` | `check-my-vibe` | The slash command shown on the status check's unblock message — what the engineer runs to clear the gate. |
| `CHECKMYVIBE_INTERVIEWER` | `pr-interview` | The interview skill `check-my-vibe` hands off to. Point it at your own skill to customize the pre-merge interview. |
| `CHECKMYVIBE_CONTEXT` | `check-my-vibe-protection` | The GitHub status check name. Must match your branch-protection required check — change both together. |
| `CHECKMYVIBE_DOCS_URL` | this README's "Unblocking a PR" | The status "Details" link. |

Example `.checkmyvibe/config`:

```sh
CHECKMYVIBE_SKILL=pr-deep-dive
CHECKMYVIBE_DOCS_URL=https://github.com/acme/dev-docs#checkmyvibe-gate
```

## Unblocking a PR

If a PR is blocked by the `check-my-vibe-protection` status, run **`/check-my-vibe`** in
Claude Code from the repo's working tree. It conducts the interview and, on your explicit
confirmation, clears the check on the PR's current head commit. (This section is what the
status's "Details" link points to.)

## Repo layout

```
action.yml                             # composite action — arms the gate on PR push (GitHub Marketplace)
scripts/set-status.sh                  # local status writer (vendored into consumers for /check-my-vibe)
scripts/install-into.sh                # vendor the gate into a target repo (from a local clone)
scripts/global-install.sh              # curl-installable install, no clone needed
templates/checkmyvibe-gate.yml       # the workflow copied into a consumer's .github/workflows
skills/check-my-vibe/SKILL.md          # the /check-my-vibe orchestrator (clears the gate)
skills/pr-interview/SKILL.md           # the interview engine check-my-vibe calls (replaceable)
PLAN.md                                # design, components, milestones
```

## License

[MIT](./LICENSE) © 2026 Jeffrey Harrison
