---
name: checkmyvibe-init
description: Vendor the CheckMyVibe gate (status writers, config, GitHub Action workflow) into the current repo, using the copies bundled alongside this skill — no toolkit clone or curl needed.
---

<!--
  Ships with the CheckMyVibe toolkit. The installer OVERWRITES the installed copy of this
  skill on every update.
-->

# CheckMyVibe: Init the gate

This skill only vendors files into the current repo — it never touches GitHub. Use it
once, per repo, to set up the optional gate on top of the `check-my-vibe` skill.

## 1. Confirm you're in a git repo

`git rev-parse --is-inside-work-tree` — if this fails, stop and tell the user to run this
from inside the target repo.

## 2. Locate the vendored gate-init script

This skill's own directory (given to you above as "Base directory for this skill") sits
alongside a `scripts/` directory two levels up — whether that's a real toolkit clone
(`skills/checkmyvibe-init/` → `../../scripts/`) or a Claude Code plugin cache
(`plugins/checkmyvibe/skills/checkmyvibe-init/` → `../../scripts/`), the relative depth is
the same. Resolve it explicitly rather than assuming:

```
GATE_INIT="$(dirname "<base-directory-shown-above>")/../scripts/gate-init.sh"
```

If that path doesn't resolve to a real file, tell the user their install looks incomplete
and to reinstall via `/plugin install checkmyvibe@checkmyvibe` or the toolkit's
`global-install.sh` / `install-into.sh`.

## 3. Run it

```
bash "$GATE_INIT" .
```

This vendors, into the current repo:

- `.checkmyvibe/set-status.sh` + `.checkmyvibe/set-review-status.sh` (gitignored, local)
- `.checkmyvibe/config` (only if one doesn't already exist)
- `.github/workflows/checkmyvibe-gate.yml`
- `scripts/validate-coverage-log.py` + `templates/coverage-log.schema.json`
- `scripts/post-skill-validate-coverage-log.sh` + `templates/settings.hooks.json`

and adds `.checkmyvibe/` to `.gitignore`.

## 4. Relay the next steps

The script prints its own next-steps block — relay it to the user verbatim rather than
summarizing, since it includes exact file paths and the required branch-protection check
name (`check-my-vibe-protection`), which must match exactly or the gate won't block merges.

Never run `git commit` or `git push` on the user's behalf here — vendoring the workflow
file is a repo change they should review and commit themselves.
