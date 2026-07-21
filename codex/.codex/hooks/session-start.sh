#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/feature-common.sh"

ROOT="${HARNESS_ROOT:-$DEFAULT_ROOT}"
STATE_DIR="${CODEX_HARNESS_STATE_DIR:-${TMPDIR:-/tmp}/aosp-codex-harness-$UID}"

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

if ! python3 - "$STATE_DIR" "$session_id" "$feature" 2>/dev/null <<'PY'
import os
import sys
import tempfile

state_dir, session_id, feature = sys.argv[1:]
destination = os.path.join(state_dir, session_id + ".feature")
descriptor = None
temporary = None

try:
    descriptor, temporary = tempfile.mkstemp(
        dir=state_dir,
        prefix="." + session_id + ".feature.tmp.",
    )
    os.fchmod(descriptor, 0o600)
    snapshot = os.fdopen(descriptor, "w", encoding="ascii", newline="\n")
    descriptor = None
    with snapshot:
        snapshot.write(feature + "\n")
        snapshot.flush()
        os.fsync(snapshot.fileno())
    os.replace(temporary, destination)
    temporary = None
finally:
    if descriptor is not None:
        os.close(descriptor)
    if temporary is not None:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
PY
then
  echo 'error: unable to record feature snapshot' >&2
  exit 1
fi
