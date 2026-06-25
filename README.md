# PR Understanding Gate

A reusable toolkit that makes an engineer demonstrate understanding of a pull request
**before it can merge** — through a private, local Claude Code interview that clears a
required GitHub status check.

- **Private:** the Q&A happens locally in Claude Code. Nothing is posted to the PR or
  visible in CI logs.
- **Enforced:** a GitHub Action arms a `understanding-check` status as *pending* on every
  push; merge is blocked until your local interview flips it to *success*.
- **Reusable:** designed to be hooked into other repos, not just this one.

Status: **planning.** See [PLAN.md](./PLAN.md) for the design, components, and milestones.
