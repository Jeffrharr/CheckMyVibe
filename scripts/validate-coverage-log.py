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


TYPE_MAP = {"integer": int, "string": str, "boolean": bool, "object": dict, "array": list}


def minimal_check(value, schema, path=""):
    """Structural check against a JSON Schema fragment, recursing into nested
    objects and array items so gaps (e.g. an empty required sub-object) aren't
    missed just because they're not at the top level."""
    errors = []

    if schema.get("type") == "object" and isinstance(value, dict):
        for key in schema.get("required", []):
            if key not in value:
                errors.append(f"{path or 'entry'}: missing required field '{key}'")

        for key, spec in schema.get("properties", {}).items():
            if key not in value:
                continue
            child_path = f"{path}.{key}" if path else key
            expected = TYPE_MAP.get(spec.get("type"))
            if expected and not isinstance(value[key], expected):
                errors.append(f"{child_path}: should be {spec['type']}, got {type(value[key]).__name__}")
                continue
            errors.extend(minimal_check(value[key], spec, child_path))

    elif schema.get("type") == "array" and isinstance(value, list):
        item_schema = schema.get("items")
        if item_schema:
            for i, item in enumerate(value):
                errors.extend(minimal_check(item, item_schema, f"{path}[{i}]"))

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
