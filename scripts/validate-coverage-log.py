#!/usr/bin/env python3
"""Validate CHECKMYVIBE_COVERAGE_LOG (JSONL) entries against
templates/coverage-log.schema.json.

Usage: validate-coverage-log.py [path-to-coverage.jsonl]
Defaults to .checkmyvibe/coverage.jsonl.

Uses the jsonschema package for full validation when it's installed
(pip install jsonschema); otherwise falls back to a minimal structural
check (required keys present, top-level types correct) so this still
catches the most common mistakes without an extra dependency.
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
SCHEMA_PATH = HERE / "templates" / "coverage-log.schema.json"


def minimal_check(entry, schema):
    errors = []
    for key in schema.get("required", []):
        if key not in entry:
            errors.append(f"missing required field '{key}'")

    type_map = {"integer": int, "string": str, "boolean": bool, "object": dict, "array": list}
    for key, spec in schema.get("properties", {}).items():
        if key not in entry:
            continue
        expected = type_map.get(spec.get("type"))
        if expected and not isinstance(entry[key], expected):
            errors.append(f"field '{key}' should be {spec['type']}, got {type(entry[key]).__name__}")
    return errors


def main():
    log_path = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / ".checkmyvibe" / "coverage.jsonl"
    if not log_path.exists():
        print(f"error: {log_path} does not exist", file=sys.stderr)
        return 1

    schema = json.loads(SCHEMA_PATH.read_text())

    try:
        import jsonschema
        validator = jsonschema.Draft7Validator(schema)
        use_jsonschema = True
    except ImportError:
        validator = None
        use_jsonschema = False
        print("note: jsonschema not installed — falling back to a minimal structural check "
              "(pip install jsonschema for full validation)", file=sys.stderr)

    ok = True
    for lineno, line in enumerate(log_path.read_text().splitlines(), start=1):
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError as e:
            print(f"line {lineno}: invalid JSON — {e}")
            ok = False
            continue

        errors = (
            [e.message for e in validator.iter_errors(entry)]
            if use_jsonschema
            else minimal_check(entry, schema)
        )
        for err in errors:
            print(f"line {lineno}: {err}")
            ok = False

    if ok:
        print(f"{log_path}: all entries valid")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
