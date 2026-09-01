#!/usr/bin/env bash

# Return success only for one safe ASCII component.  This predicate is quiet so
# callers can map failures to their own public API error contract.
_harness_component_is_safe() {
  LC_ALL=C
  [[ $# == 1 && ${#1} -ge 1 && ${#1} -le 128 && $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

harness_validate_feature_name() {
  [[ $# == 1 ]] && _harness_component_is_safe "$1" || {
    printf '%s\n' 'error: invalid feature name' >&2
    return 2
  }
}

_harness_session_state_run() (
  if [[ $# != 3 ]]; then
    printf '%s\n' 'error: unsafe session state' >&2
    return 2
  fi
  if [[ $1 != path ]] || ! _harness_component_is_safe "$2" || ! _harness_component_is_safe "$3"; then
    printf '%s\n' 'error: unsafe session state' >&2
    return 2
  fi
  umask 077
  python3 - "$@" <<'PY'
import errno, os, pathlib, stat, sys
class UnsafeState(Exception): pass
class OperationFailure(Exception): pass
OPEN_DIR = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC

def _checked_path(value, reject_root=False):
    if (not value or not os.path.isabs(value)
            or any(ord(char) < 32 or ord(char) == 127 for char in value)
            or any(part in (".", "..") for part in value.split("/"))):
        raise UnsafeState
    normalized = os.path.normpath(value)
    if reject_root and normalized == "/":
        raise UnsafeState
    return normalized

def _path_error(exc):
    if isinstance(exc, (FileNotFoundError, NotADirectoryError)) or getattr(
            exc, "errno", None) == errno.ELOOP:
        raise UnsafeState from exc
    raise OperationFailure from exc

def _physical_directory(value):
    try:
        physical = str(pathlib.Path(value).resolve(strict=True))
        info = os.stat(physical, follow_symlinks=False)
    except RuntimeError as exc:
        raise UnsafeState from exc
    except OSError as exc:
        _path_error(exc)
    if not stat.S_ISDIR(info.st_mode):
        raise UnsafeState
    return physical

def _select_state_root(env, euid):
    if "HARNESS_STATE_ROOT" in env:
        root = _checked_path(env["HARNESS_STATE_ROOT"], reject_root=True)
        parent, leaf = os.path.split(root)
        return _physical_directory(parent), leaf
    if "XDG_RUNTIME_DIR" in env:
        base = _checked_path(env["XDG_RUNTIME_DIR"])
    else:
        base = _checked_path(env.get("TMPDIR") or "/tmp")
    return _physical_directory(base), f"aosp-harness-{euid}"

def _open_fresh(parent_fd, name):
    made = False
    try:
        try:
            os.mkdir(name, 0o700, dir_fd=parent_fd)
            made = True
        except FileExistsError:
            pass
        fd = os.open(name, OPEN_DIR, dir_fd=parent_fd)
    except OSError as exc:
        _path_error(exc)
    try:
        if made:
            os.fchmod(fd, 0o700)
        return fd
    except OSError as exc:
        os.close(fd)
        raise OperationFailure from exc

def _dispatch_path(project, session):
    physical_parent, root_leaf = _select_state_root(os.environ, os.geteuid())
    fds = []
    try:
        try:
            parent_fd = os.open(physical_parent, OPEN_DIR)
        except OSError as exc:
            _path_error(exc)
        fds.append(parent_fd)
        for name in (root_leaf, project, session):
            fds.append(_open_fresh(fds[-1], name))
        return os.path.join(physical_parent, root_leaf, project, session)
    finally:
        for fd in reversed(fds):
            os.close(fd)

try:
    if len(sys.argv) != 4 or sys.argv[1] != "path":
        raise UnsafeState
    print(_dispatch_path(sys.argv[2], sys.argv[3]))
except UnsafeState:
    print("error: unsafe session state", file=sys.stderr)
    raise SystemExit(2)
except (OSError, OperationFailure):
    print("error: session state operation failed", file=sys.stderr)
    raise SystemExit(1)
PY
)

_harness_session_state_foundation_path() {
  if [[ $# != 2 ]] || ! _harness_component_is_safe "$1" || ! _harness_component_is_safe "$2"; then
    printf '%s\n' 'error: unsafe session state' >&2
    return 2
  fi
  _harness_session_state_run path "$1" "$2"
}
