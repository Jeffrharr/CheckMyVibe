#!/usr/bin/env python3
"""Exercise scripts/validate-coverage-log.py against mock pr-interview output.

Each case stands in for a coverage-log line an LLM would produce after
actually running pr-interview: a session where its mind changed, one where
the engineer surfaced an issue, one where the AI did, and the malformed
variants a schema change like this needs to guard against. Run directly:
scripts/test-coverage-log-schema.py
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
VALIDATOR = HERE / "scripts" / "validate-coverage-log.py"

BASE = {
    "date": "2026-07-15",
    "pr": 42,
    "branch": "feature/mock-interview",
    "understanding_pct": 93,
    "recommendation": "clear to merge",
    "coverage": {
        "changed_lines_pct": 90,
        "control_flow_pct": 80,
        "functions_explained_pct": 100,
        "dependencies_understood_pct": 90,
    },
    "robustness": {
        "objections_raised": 2,
        "objections_resolved": 2,
        "reviewer_changed_position": 1,
        "unsupported_assumptions_remaining": 0,
    },
    "mind_changed": False,
}


def entry(**overrides):
    e = json.loads(json.dumps(BASE))  # deep copy
    e.update(overrides)
    return e


CASES = [
    (
        "mind changed, with a what/how/why summary",
        entry(
            mind_changed=True,
            mind_changed_summary={
                "what": "moved the permission check before the cache write",
                "how": "engineer traced a race condition after being asked about concurrent writes",
                "why": "closes a window where a revoked permission is still served from cache",
            },
        ),
        True,
    ),
    (
        "engineer surfaced an issue, AI surfaced a different one",
        entry(
            engineer_surfaced_issues=[
                {
                    "what": "retry counter isn't reset after a successful send",
                    "how": "engineer noticed it while walking through the retry loop for an unrelated question",
                    "why": "would under-count retries on the very next failure",
                }
            ],
            ai_surfaced_issues=[
                {
                    "what": "webhook signature isn't checked before the payload is processed",
                    "how": "asked what stops a forged request from reaching the handler",
                    "why": "unauthenticated input was reaching business logic unchecked",
                }
            ],
        ),
        True,
    ),
    (
        "mind_changed true with no summary (legacy entries predate this field)",
        entry(mind_changed=True),
        True,
    ),
    (
        "no issues surfaced, empty arrays",
        entry(engineer_surfaced_issues=[], ai_surfaced_issues=[]),
        True,
    ),
    (
        "mind_changed_summary missing 'why'",
        entry(
            mind_changed=True,
            mind_changed_summary={"what": "x", "how": "y"},
        ),
        False,
    ),
    (
        "engineer_surfaced_issues item missing 'how'",
        entry(engineer_surfaced_issues=[{"what": "x", "why": "z"}]),
        False,
    ),
    (
        "ai_surfaced_issues item has an unexpected extra key",
        entry(
            ai_surfaced_issues=[
                {"what": "x", "how": "y", "why": "z", "severity": "high"}
            ]
        ),
        False,
    ),
    (
        "engineer_surfaced_issues is not a list",
        entry(engineer_surfaced_issues={"what": "x", "how": "y", "why": "z"}),
        False,
    ),
]


def run_case(name, data, expect_valid):
    with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False) as f:
        f.write(json.dumps(data) + "\n")
        path = f.name
    result = subprocess.run(
        [sys.executable, str(VALIDATOR), path],
        capture_output=True,
        text=True,
    )
    Path(path).unlink(missing_ok=True)

    passed = (result.returncode == 0) == expect_valid
    print(f"[{'ok' if passed else 'FAIL'}] {name}")
    if not passed:
        print(f"    expected {'valid' if expect_valid else 'invalid'}, got exit={result.returncode}")
        if result.stdout.strip():
            print("    " + result.stdout.strip().replace("\n", "\n    "))
    return passed


def main():
    results = [run_case(name, data, expect_valid) for name, data, expect_valid in CASES]
    print()
    print(f"{sum(results)}/{len(results)} cases passed")
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
