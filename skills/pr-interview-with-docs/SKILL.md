---
name: pr-interview-with-docs
description: A pre-merge PR interview that also sharpens the domain model as it goes, capturing glossary terms and ADRs the diff surfaces.
disable-model-invocation: true
---

Run a `/pr-interview` session, using the `/domain-modeling` skill.

When the interview surfaces a fuzzy or contested term, a code/language mismatch, or a hard-to-reverse decision baked into the diff, pause and resolve it with `/domain-modeling` right there — update `CONTEXT.md` or write the ADR before returning to the next question. Don't let the interview finish with a term still fuzzy.

## PR coverage metric

At conclusion, alongside the usual pr-interview summary, report how much of the
diff's substantive code got discussed:

- For each changed file with actual logic (skip pure boilerplate: imports,
  docstrings, `__init__` bodies with no branching), note which changed
  lines/functions were touched by a question versus untouched.
- Report as `covered / substantive changed lines` and a percentage, e.g.
  `"38/42 lines (90%) — untouched: module docstring, Order.__init__"`.
- Judgment calls on what counts as "substantive" are fine — state what you
  excluded and why in one line, don't over-formalize this.

## Logging the metric

Read `CHECKMYVIBE_COVERAGE_LOG` from `.checkmyvibe/config` (or the
environment; same lookup pattern as `check-my-vibe`'s other `CHECKMYVIBE_*`
vars — `cat .checkmyvibe/config 2>/dev/null | grep CHECKMYVIBE_COVERAGE_LOG`).

If it's set, append one line to that path (create the file and any parent
directory if missing) as a JSON object:

```json
{"date": "2026-07-07", "pr": 18, "branch": "demo/dummy-domain-model", "covered_lines": 38, "substantive_lines": 42, "coverage_pct": 90}
```

If the variable is unset, skip logging entirely — don't create the file. This
is opt-in, not a default-on side effect.
