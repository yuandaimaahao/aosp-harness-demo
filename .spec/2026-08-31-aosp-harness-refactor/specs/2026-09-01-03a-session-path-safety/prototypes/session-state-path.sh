#!/usr/bin/env bash
# Throwaway sizing skeleton: executable design proof, not production code.
declare -F harness_validate_feature_name >/dev/null || return 0
declare -F _harness_session_state_foundation_path >/dev/null || return 0
declare -F _harness_session_state_run >/dev/null || return 0

_harness_session_path_core() (
  unsafe() { printf '%s\n' 'error: unsafe session state' >&2; return 2; }
  [[ $# == 2 ]] || { unsafe; return; }
  harness_validate_feature_name "$1" >/dev/null 2>&1 || { unsafe; return; }
  harness_validate_feature_name "$2" >/dev/null 2>&1 || { unsafe; return; }
  umask 077
  python3 - "$1" "$2" <<'PY'
import errno, os, pathlib, stat, sys
class UnsafeState(Exception): pass
class OperationFailure(Exception): pass
OPEN_DIR = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC

def checked_path(value, reject_root=False):
    if (not value or not os.path.isabs(value)
            or any(ord(c) < 32 or ord(c) == 127 for c in value)
            or any(p in (".", "..") for p in value.split("/"))):
        raise UnsafeState
    value = os.path.normpath(value)
    if reject_root and value == "/":
        raise UnsafeState
    return value

def path_error(exc):
    if isinstance(exc, (FileNotFoundError, NotADirectoryError)) or getattr(
            exc, "errno", None) == errno.ELOOP:
        raise UnsafeState from exc
    raise OperationFailure from exc

def managed_open_error(exc):
    if getattr(exc, "errno", None) in (errno.ELOOP, errno.ENOTDIR):
        raise UnsafeState from exc
    raise OperationFailure from exc

def physical_dir(value):
    try:
        value = str(pathlib.Path(value).resolve(strict=True))
        info = os.stat(value, follow_symlinks=False)
    except RuntimeError as exc:
        raise UnsafeState from exc
    except OSError as exc:
        path_error(exc)
    if not stat.S_ISDIR(info.st_mode):
        raise UnsafeState
    return value

def select_root():
    if "HARNESS_STATE_ROOT" in os.environ:
        root = checked_path(os.environ["HARNESS_STATE_ROOT"], True)
        parent, leaf = os.path.split(root)
        return physical_dir(parent), leaf
    if "XDG_RUNTIME_DIR" in os.environ:
        base = checked_path(os.environ["XDG_RUNTIME_DIR"])
    else:
        base = checked_path(os.environ.get("TMPDIR") or "/tmp")
    return physical_dir(base), f"aosp-harness-{os.geteuid()}"

def same_object(left, right):
    return (left.st_dev, left.st_ino, stat.S_IFMT(left.st_mode)) == (
        right.st_dev, right.st_ino, stat.S_IFMT(right.st_mode))

def _managed_checkpoint(phase, parent_fd, name, made):
    pass  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN

def open_managed(parent_fd, name):
    made = False
    try:
        before = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
    except FileNotFoundError:
        _managed_checkpoint("before_mkdir", parent_fd, name, made)
        try:
            os.mkdir(name, 0o700, dir_fd=parent_fd)
            made = True
            before = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
        except FileExistsError:
            pass  # provider-copy catch sentinel is injected here
            _managed_checkpoint("after_eexist", parent_fd, name, made)
            try:
                before = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
            except OSError as exc:
                raise OperationFailure from exc
        except OSError as exc:
            path_error(exc)
    except OSError as exc:
        path_error(exc)
    _managed_checkpoint("before_open", parent_fd, name, made)
    if not stat.S_ISDIR(before.st_mode):
        raise UnsafeState
    try:
        child_fd = os.open(name, OPEN_DIR, dir_fd=parent_fd)
        current = os.fstat(child_fd)
    except OSError as exc:
        managed_open_error(exc)
    expected_euid = os.geteuid()  # HARNESS_TEST_MARKER_EXPECTED_EUID
    if (not same_object(before, current) or current.st_uid != expected_euid
            or stat.S_IMODE(current.st_mode) != 0o700):
        os.close(child_fd)
        raise UnsafeState
    try:
        after = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
    except OSError as exc:
        os.close(child_fd)
        raise OperationFailure from exc
    if not same_object(after, current):
        os.close(child_fd)
        raise UnsafeState
    return child_fd

def dispatch(project, session):
    parent, root = select_root()
    fds = []
    try:
        pass  # HARNESS_TEST_MARKER_OS_ERROR
        fds.append(os.open(parent, OPEN_DIR))
        for name in (root, project, session):
            fds.append(open_managed(fds[-1], name))
        return os.path.join(parent, root, project, session)
    finally:
        for child_fd in reversed(fds):
            os.close(child_fd)

try:
    print(dispatch(sys.argv[1], sys.argv[2]))
except UnsafeState:
    print("error: unsafe session state", file=sys.stderr)
    raise SystemExit(2)
except (OSError, OperationFailure):
    print("error: session state operation failed", file=sys.stderr)
    raise SystemExit(1)
PY
)
