#!/usr/bin/env python3
"""Validate CHECKMYVIBE_COVERAGE_LOG (JSONL) entries against
templates/coverage-log.schema.json.

Usage: validate-coverage-log.py [path-to-coverage.jsonl]
Defaults to .checkmyvibe/coverage.jsonl.

Stdlib-only structural check (required fields, types, additionalProperties,
pattern/minLength/minimum/maximum), recursing into nested objects and array
items. Not a full JSON Schema implementation — covers the constraint kinds
this toolkit's schemas actually use.
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
SCHEMA_PATH = HERE / "templates" / "coverage-log.schema.json"

TYPE_MAP = {"integer": int, "string": str, "boolean": bool, "object": dict, "array": list}


def check_value(key_path, value, spec, errors):
    expected = TYPE_MAP.get(spec.get("type"))
    if expected and not isinstance(value, expected):
        errors.append(f"{key_path}: should be {spec['type']}, got {type(value).__name__}")
        return

    if "pattern" in spec and isinstance(value, str) and not re.match(spec["pattern"], value):
        errors.append(f"{key_path}: '{value}' does not match pattern '{spec['pattern']}'")
    if "minLength" in spec and isinstance(value, str) and len(value) < spec["minLength"]:
        errors.append(f"{key_path}: length {len(value)} is less than minLength {spec['minLength']}")
    if "minimum" in spec and isinstance(value, (int, float)) and value < spec["minimum"]:
        errors.append(f"{key_path}: {value} is less than minimum {spec['minimum']}")
    if "maximum" in spec and isinstance(value, (int, float)) and value > spec["maximum"]:
        errors.append(f"{key_path}: {value} is greater than maximum {spec['maximum']}")

    errors.extend(minimal_check(value, spec, key_path))


def minimal_check(value, schema, path=""):
    """Structural check against a JSON Schema fragment, recursing into nested
    objects and array items so gaps aren't missed just because they're not
    at the top level."""
    errors = []

    if schema.get("type") == "object" and isinstance(value, dict):
        for key in schema.get("required", []):
            if key not in value:
                errors.append(f"{path or 'entry'}: missing required field '{key}'")

        properties = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            for key in value:
                if key not in properties:
                    errors.append(f"{path or 'entry'}: unexpected field '{key}' (not in schema)")

        for key, spec in properties.items():
            if key not in value:
                continue
            child_path = f"{path}.{key}" if path else key
            check_value(child_path, value[key], spec, errors)

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

        for err in minimal_check(entry, schema):
            print(f"line {lineno}: {err}")
            ok = False

    if ok:
        print(f"{log_path}: all entries valid")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
