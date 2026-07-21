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
sys.stdout.buffer.write(session_id.encode("ascii"))
'
}

prepare_state_dir() {
  python3 - "$1" <<'PY'
import os
import stat
import sys

raw_path = sys.argv[1]
if not raw_path or any(ord(character) < 32 or ord(character) == 127 for character in raw_path):
    raise SystemExit(1)
raw_components = raw_path.split(os.sep)
if any(component in (".", "..") for component in raw_components):
    raise SystemExit(1)

components = [component for component in raw_components if component]
if not components:
    raise SystemExit(1)

absolute = os.path.isabs(raw_path)
normalized = os.path.join(*components)
if absolute:
    normalized = os.sep + normalized

open_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
if hasattr(os, "O_CLOEXEC"):
    open_flags |= os.O_CLOEXEC

directory_fd = os.open(os.sep if absolute else ".", open_flags)
try:
    for component in components:
        created = False
        try:
            component_stat = os.lstat(component, dir_fd=directory_fd)
        except FileNotFoundError:
            try:
                os.mkdir(component, mode=0o700, dir_fd=directory_fd)
                created = True
            except FileExistsError:
                pass
            component_stat = os.lstat(component, dir_fd=directory_fd)

        if stat.S_ISLNK(component_stat.st_mode):
            raise SystemExit(1)
        if not stat.S_ISDIR(component_stat.st_mode):
            raise SystemExit(1)

        next_fd = os.open(component, open_flags, dir_fd=directory_fd)
        os.close(directory_fd)
        directory_fd = next_fd
        if created:
            os.fchmod(directory_fd, 0o700)
            created_stat = os.fstat(directory_fd)
            if created_stat.st_uid != os.getuid():
                raise SystemExit(1)
            if stat.S_IMODE(created_stat.st_mode) != 0o700:
                raise SystemExit(1)

    final_stat = os.fstat(directory_fd)
    if final_stat.st_uid != os.getuid():
        raise SystemExit(1)
    os.fchmod(directory_fd, 0o700)
    final_stat = os.fstat(directory_fd)
    if not stat.S_ISDIR(final_stat.st_mode):
        raise SystemExit(1)
    if stat.S_IMODE(final_stat.st_mode) != 0o700:
        raise SystemExit(1)
finally:
    os.close(directory_fd)

sys.stdout.buffer.write(os.fsencode(normalized))
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
if ! STATE_DIR="$(prepare_state_dir "$STATE_DIR" 2>/dev/null)"; then
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
