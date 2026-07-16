#!/usr/bin/env python3
"""Finalize a check-my-vibe run's token usage. Called from
scripts/stop-log-token-usage.sh once a start marker is found for the
current session.

No-ops (exit 0, marker left in place) unless check-my-vibe has signaled
completion — a .checkmyvibe/token-usage/.markers/.checkmyvibe-complete
sentinel with an mtime at or after the marker's created_at_epoch (touched by
check-my-vibe/SKILL.md as its literal last action, on both the gate-cleared
and declined paths). Once that's true:

1. Consume (delete) the sentinel immediately.
2. Sum main-session usage from the transcript slice
   [transcript_line_count_at_start : end].
3. Find every Task/Agent tool call in that slice; use its toolUseResult's own
   usage rollup (computed by the harness) as that subagent's total, and read
   its own transcript file for a per-turn breakdown.
4. Merge a `token_usage` rollup into the newest coverage-log line that
   doesn't already have one.
5. Write the full per-turn breakdown to a companion detail file under
   .checkmyvibe/token-usage/<session_id>.json.
6. Best-effort re-validate the coverage log with validate-coverage-log.py.
7. Delete the marker.
"""
import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

USAGE_FIELDS = ("input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens")
SUBAGENT_TOOL_NAMES = ("Task", "Agent")


def zero_usage():
    return {k: 0 for k in USAGE_FIELDS}


def add_usage(total, usage):
    for k in USAGE_FIELDS:
        total[k] += int((usage or {}).get(k, 0) or 0)


def read_jsonl(path: Path):
    entries = []
    if not path.exists():
        return entries
    with path.open("r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return entries


def sum_transcript_usage(lines):
    total = zero_usage()
    itemized = []
    for i, entry in enumerate(lines):
        if entry.get("type") != "assistant":
            continue
        usage = (entry.get("message") or {}).get("usage")
        if not usage:
            continue
        add_usage(total, usage)
        itemized.append({"turn": i, **{k: int(usage.get(k, 0) or 0) for k in USAGE_FIELDS}})
    return total, itemized


def find_subagent_calls(slice_lines):
    """Scan a transcript slice for Task/Agent tool calls, returning each
    call's agentId/agentType plus the harness-computed usage rollup found on
    its toolUseResult, wherever in the entry that field lives."""
    calls = []
    for entry in slice_lines:
        tool_use_result = entry.get("toolUseResult")
        if not isinstance(tool_use_result, dict):
            continue
        agent_id = tool_use_result.get("agentId")
        if not agent_id:
            continue
        # Only count entries that actually look like a subagent dispatch —
        # guard against unrelated tool results that happen to share shape.
        message = entry.get("message") or {}
        content = message.get("content")
        is_subagent_tool_result = isinstance(content, list) and any(
            isinstance(block, dict) and block.get("type") == "tool_result"
            for block in content
        )
        if not is_subagent_tool_result and "agentType" not in tool_use_result:
            continue
        calls.append({
            "agent_id": agent_id,
            "agent_type": tool_use_result.get("agentType") or "unknown",
            "usage": tool_use_result.get("usage"),
        })
    return calls


def resolve_subagents(transcript_path: Path, slice_lines):
    subagents_dir = transcript_path.parent / "subagents"
    results = []
    seen_agent_ids = set()
    for call in find_subagent_calls(slice_lines):
        agent_id = call["agent_id"]
        if agent_id in seen_agent_ids:
            continue
        seen_agent_ids.add(agent_id)

        sub_transcript = subagents_dir / f"agent-{agent_id}.jsonl"
        sub_lines = read_jsonl(sub_transcript)
        computed_total, turns = sum_transcript_usage(sub_lines)

        # Prefer the harness's own rollup on toolUseResult when present —
        # authoritative and cheaper than re-summing. Fall back to the
        # locally-computed total (e.g. if usage wasn't attached there).
        total = zero_usage()
        if call["usage"]:
            add_usage(total, call["usage"])
        else:
            total = computed_total

        agent_type = call["agent_type"]
        if agent_type == "unknown":
            meta_path = subagents_dir / f"agent-{agent_id}.meta.json"
            if meta_path.exists():
                try:
                    meta = json.loads(meta_path.read_text(encoding="utf-8"))
                    agent_type = meta.get("agentType") or agent_type
                except Exception:
                    pass

        results.append({"agent_id": agent_id, "agent_type": agent_type, "total": total, "turns": turns})
    return results


def atomic_write(path: Path, content: str):
    tmp = path.with_suffix(path.suffix + f".tmp.{os.getpid()}")
    with tmp.open("w", encoding="utf-8") as fh:
        fh.write(content)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, path)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--here", required=True)
    ap.add_argument("--marker", required=True)
    args = ap.parse_args()

    here = Path(args.here)
    marker_path = Path(args.marker)
    try:
        marker = json.loads(marker_path.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"error: unreadable marker {marker_path}: {e}", file=sys.stderr)
        marker_path.unlink(missing_ok=True)
        return 1

    sentinel_path = here / ".checkmyvibe" / "token-usage" / ".markers" / ".checkmyvibe-complete"
    if not sentinel_path.exists() or sentinel_path.stat().st_mtime < marker["created_at_epoch"]:
        return 0  # check-my-vibe hasn't finished yet; leave marker in place

    sentinel_path.unlink(missing_ok=True)  # consume immediately

    transcript_path = Path(marker["transcript_path"])
    all_transcript = read_jsonl(transcript_path)
    start_line = marker["transcript_line_count_at_start"]
    slice_lines = all_transcript[start_line:]

    main_total, main_turns = sum_transcript_usage(slice_lines)
    subagents = resolve_subagents(transcript_path, slice_lines)

    grand_total = zero_usage()
    add_usage(grand_total, main_total)
    subagents_rollup = []
    for sa in subagents:
        add_usage(grand_total, sa["total"])
        subagents_rollup.append({"agent_type": sa["agent_type"], **sa["total"]})

    session_id = marker["session_id"]
    detail_dir = here / ".checkmyvibe" / "token-usage"
    detail_dir.mkdir(parents=True, exist_ok=True)
    detail_path = detail_dir / f"{session_id}.json"

    # Merge into the newest coverage-log line that doesn't already have
    # token_usage (search backward — robust against an unrelated later
    # append landing between the marker and this finalize run).
    config_path_env = os.environ.get("CHECKMYVIBE_CONFIG")
    config_path = Path(config_path_env) if config_path_env else here / ".checkmyvibe" / "config"
    log_path_str = os.environ.get("CHECKMYVIBE_COVERAGE_LOG", "")
    if not log_path_str and config_path.exists():
        for cfg_line in config_path.read_text(encoding="utf-8", errors="replace").splitlines():
            if cfg_line.startswith("CHECKMYVIBE_COVERAGE_LOG="):
                log_path_str = cfg_line.split("=", 1)[1].strip()
                break
    log_path = Path(log_path_str) if log_path_str else None
    if log_path and not log_path.is_absolute():
        log_path = here / log_path

    merged_pr = None
    merged_branch = None
    if log_path and log_path.exists():
        with log_path.open("r", encoding="utf-8", errors="replace") as fh:
            current_lines = fh.readlines()

        target_index = None
        target_entry = None
        for i in range(len(current_lines) - 1, -1, -1):
            raw = current_lines[i].strip()
            if not raw:
                continue
            try:
                candidate = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if "token_usage" not in candidate:
                target_index, target_entry = i, candidate
                break

        if target_entry is not None:
            merged_pr = target_entry.get("pr")
            merged_branch = target_entry.get("branch")
            target_entry["token_usage"] = {
                "main": main_total,
                "subagents": subagents_rollup,
                "total": grand_total,
                "detail_file": str(detail_path.relative_to(here)),
            }
            current_lines[target_index] = json.dumps(target_entry) + "\n"
            atomic_write(log_path, "".join(current_lines))

            validator = here / "scripts" / "validate-coverage-log.py"
            if validator.exists():
                result = subprocess.run([sys.executable, str(validator), str(log_path)],
                                         capture_output=True, text=True)
                if result.returncode != 0:
                    print("warning: coverage log failed validation after token_usage merge:", file=sys.stderr)
                    print(result.stdout, file=sys.stderr)
        else:
            print(f"warning: no coverage-log line without token_usage found in {log_path} "
                  f"— writing detail file only", file=sys.stderr)
    else:
        print("warning: CHECKMYVIBE_COVERAGE_LOG not resolvable — writing detail file only", file=sys.stderr)

    detail = {
        "session_id": session_id,
        "pr": merged_pr,
        "branch": merged_branch,
        "finalized_at_epoch": int(time.time()),
        "main": {"total": main_total, "turns": main_turns},
        "subagents": [
            {"agent_id": sa["agent_id"], "agent_type": sa["agent_type"], "total": sa["total"], "turns": sa["turns"]}
            for sa in subagents
        ],
        "grand_total": grand_total,
    }
    atomic_write(detail_path, json.dumps(detail, indent=2) + "\n")

    marker_path.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
