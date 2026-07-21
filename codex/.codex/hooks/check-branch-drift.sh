#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/feature-common.sh"

ROOT="${HARNESS_ROOT:-$DEFAULT_ROOT}"
STATE_DIR="${CODEX_HARNESS_STATE_DIR:-${TMPDIR:-/tmp}/aosp-codex-harness-$UID}"
SYSTEM_MESSAGE='Feature changed during this Codex session. Restart with ./.codex/bin/codex-feature before continuing.'

parse_session_id() {
  python3 -c '
import json
import re
import sys

try:
    data = json.load(sys.stdin)
    session_id = data["session_id"]
except (json.JSONDecodeError, KeyError, TypeError):
    raise SystemExit(1)

if not isinstance(session_id, str):
    raise SystemExit(1)
if not 1 <= len(session_id) <= 128:
    raise SystemExit(1)
if session_id in (".", ".."):
    raise SystemExit(1)
if re.fullmatch(r"[A-Za-z0-9._-]+", session_id) is None:
    raise SystemExit(1)
sys.stdout.write(session_id)
'
}

prepare_state_dir() {
  local state_dir="$1"

  if [[ -L "$state_dir" ]]; then
    return 1
  fi
  if [[ -e "$state_dir" ]]; then
    [[ -d "$state_dir" && -O "$state_dir" ]] || return 1
  else
    mkdir -m 700 -- "$state_dir" 2>/dev/null || return 1
  fi
  [[ ! -L "$state_dir" && -d "$state_dir" && -O "$state_dir" ]] || return 1
  chmod 700 -- "$state_dir" 2>/dev/null
}

normalize_state_dir() {
  local state_dir="$1"

  while [[ "$state_dir" == */ && "$state_dir" != '/' ]]; do
    state_dir="${state_dir%/}"
  done
  printf '%s\n' "$state_dir"
}

emit_stop() {
  local stop_reason="$1"

  python3 - "$stop_reason" "$SYSTEM_MESSAGE" <<'PY'
import json
import sys

stop_reason, system_message = sys.argv[1:]
sys.stdout.write(json.dumps({
    "continue": False,
    "stopReason": stop_reason,
    "systemMessage": system_message,
}) + "\n")
PY
}

if ! session_id="$(parse_session_id 2>/dev/null)"; then
  echo 'error: invalid hook input' >&2
  exit 1
fi

if ! feature="$(detect_feature "$ROOT")"; then
  echo 'error: unable to detect active feature' >&2
  exit 1
fi
if ! feature_context_path "$ROOT" "$feature" >/dev/null; then
  echo 'error: active feature context is unavailable' >&2
  exit 1
fi

umask 077
STATE_DIR="$(normalize_state_dir "$STATE_DIR")"
if ! prepare_state_dir "$STATE_DIR"; then
  echo 'error: unsafe harness state directory' >&2
  exit 1
fi

snapshot="$STATE_DIR/$session_id.feature"
if [[ ! -e "$snapshot" && ! -L "$snapshot" ]]; then
  emit_stop "AOSP feature snapshot is missing for session '$session_id'. Restart the Codex session before continuing."
  exit 0
fi
if [[ -L "$snapshot" || ! -f "$snapshot" || ! -O "$snapshot" ]]; then
  echo 'error: unsafe feature snapshot' >&2
  exit 1
fi

if ! snapshot_feature="$(python3 - "$snapshot" 2>/dev/null <<'PY'
import re
import sys

try:
    data = open(sys.argv[1], "rb").read()
except OSError:
    raise SystemExit(1)
match = re.fullmatch(rb"([A-Za-z0-9][A-Za-z0-9._-]*)(?:\n)?", data)
if match is None:
    raise SystemExit(1)
sys.stdout.buffer.write(match.group(1))
PY
)"; then
  echo 'error: invalid feature snapshot' >&2
  exit 1
fi

if [[ "$snapshot_feature" == "$feature" ]]; then
  exit 0
fi

emit_stop "AOSP feature drift: session started on '$snapshot_feature', current feature is '$feature'."
