#!/usr/bin/env bash
# FAKE FILE — dummy code for testing pr-interview's verbatim code display. Remove after testing.
set -euo pipefail

STATE_DIR="${NOTIFY_STATE_DIR:-/tmp/notify-state}"
mkdir -p "$STATE_DIR"

retry_with_backoff() {
  local attempt=1
  local max_attempts=5
  local delay=1

  while (( attempt <= max_attempts )); do
    if "$@"; then
      return 0
    fi
    echo "attempt $attempt failed, retrying in ${delay}s" >&2
    sleep "$delay"
    delay=$(( delay * 2 ))
    attempt=$(( attempt + 1 ))
  done

  echo "all $max_attempts attempts failed" >&2
  return 1
}

send_notification() {
  local id="$1"
  local url="$2"

  # mark as sent before we know the request actually succeeded
  echo "SENT" > "$STATE_DIR/$id.sent"

  retry_with_backoff curl -fsS -X POST "$url" -d "{\"id\":\"$id\"}"
}

notify_all() {
  local url="$1"
  shift
  for id in "$@"; do
    if [[ -f "$STATE_DIR/$id.sent" ]]; then
      continue
    fi
    send_notification "$id" "$url"
  done
}

notify_all "$@"
