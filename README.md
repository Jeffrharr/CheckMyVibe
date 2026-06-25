# PR Understanding Gate

A reusable toolkit that makes an engineer demonstrate understanding of a pull request
**before it can merge** — through a private, local Claude Code interview that clears a
required GitHub status check.

- **Private** — the Q&A happens locally in Claude Code. Nothing is posted to the PR or
  visible in CI logs; only a one-line status flip touches GitHub.
- **Enforced** — a GitHub Action arms an `understanding-check` status as *pending* on every
  push; the PR cannot merge until your local interview flips it to *success*.
- **Reusable** — vendor it into any repo with one command.

See [PLAN.md](./PLAN.md) for the full design and rationale.

## How it works

A GitHub Action can't push an interactive chat onto your laptop, so the arrow is inverted:
the local interview is what unblocks the PR.

```
develop in Claude Code
        │
        ▼
/understanding-check  ──►  Claude interviews you (local, private)
        │                          │
        │                  "understanding confirmed"
        │                          ▼
        │            .understanding/set-status.sh success  (gh api statuses/<sha>)
        ▼                          │
 Action arms pending  ─►  required status check ─►  merge unblocked
 on each push (CI)                 ▲
                                   │
                  pushing new commits re-arms pending
```

Because the status is written per commit SHA, pushing new commits resets the gate to
`pending` — so the check always reflects the *current* code.

## Install into a repo

```sh
scripts/install-into.sh /path/to/target-repo            # skill lives in the target repo
scripts/install-into.sh /path/to/target-repo --global-skill   # skill in ~/.claude/skills
```

This vendors three things into the target repo (no runtime dependency on this toolkit):

- `.understanding/set-status.sh` — the shared status writer
- `.github/workflows/understanding-gate.yml` — arms `understanding-check` pending per PR push
- the `/understanding-check` skill — the local interview

Then, in the target repo:

1. Commit the vendored files.
2. **Branch protection → Require status checks to pass →** add a required check named exactly
   `understanding-check`. This is what actually blocks merges. (The workflow still arms the
   check and the `/understanding-check` flow still works without this step — but nothing is
   *enforced* until the check is required.)

> **Note:** Required status checks need branch protection, which on GitHub's free tier is
> only available for **public** repos (private repos need Pro/Team). Without it, the gate is
> advisory — the check shows on PRs but doesn't block merge.

## Usage

1. Open a PR. The gate posts `understanding-check = pending` and the merge button is blocked.
2. When you're ready to merge, run `/understanding-check` in Claude Code. It pulls the diff
   and interviews you about the change.
3. Once you've shown you understand it and confirm, the skill flips the check to `success`
   and the PR can merge.

## Configuration

The gate reads optional settings from `.understanding/config` (created by the installer),
overridable by environment variables. Precedence: **built-in default < `.understanding/config` < env**.

| Setting | Default | Controls |
|---|---|---|
| `UNDERSTANDING_SKILL` | `understanding-check` | The slash command shown in the check's unblock message. Point it at your own interview skill if you've made one. |
| `UNDERSTANDING_CONTEXT` | `understanding-check` | The GitHub status check name. Must match your branch-protection required check — change both together. |
| `UNDERSTANDING_DOCS_URL` | this README's "Unblocking a PR" | The status "Details" link. |

Example `.understanding/config`:

```sh
UNDERSTANDING_SKILL=pr-deep-dive
UNDERSTANDING_DOCS_URL=https://github.com/acme/dev-docs#understanding-gate
```

## Unblocking a PR

If a PR is blocked by the `understanding-check` status, run **`/understanding-check`** in
Claude Code from the repo's working tree. It conducts the interview and, on your explicit
confirmation, clears the check on the PR's current head commit. (This section is what the
status's "Details" link points to.)

## Repo layout

```
scripts/set-status.sh                  # shared gh status writer (vendored into consumers)
scripts/install-into.sh                # vendor the gate into a target repo
templates/understanding-gate.yml       # the workflow copied into a consumer's .github/workflows
skills/understanding-check/SKILL.md     # the /understanding-check interview
PLAN.md                                # design, components, milestones
```

This repo **dogfoods its own gate**: `.github/workflows/understanding-gate.yml` arms the
check on its PRs, with `.understanding/set-status.sh` and `.claude/skills/.../SKILL.md`
symlinked to the canonical sources above (so there's no drift).

## License

[MIT](./LICENSE) © 2026 Jeffrey Harrison
