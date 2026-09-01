#!/usr/bin/env bash
if declare -F harness_validate_feature_name >/dev/null \
  && declare -F _harness_session_state_foundation_path >/dev/null \
  && declare -F _harness_session_state_run >/dev/null; then
  _harness_session_path_core() (
    if [[ $# != 2 ]] \
      || ! harness_validate_feature_name "$1" >/dev/null 2>&1 \
      || ! harness_validate_feature_name "$2" >/dev/null 2>&1; then
      printf '%s\n' 'error: unsafe session state' >&2
      return 2
    fi
    umask 077
    python3 - "$1" "$2" <<'PY'
import errno, os, pathlib, stat, sys
class UnsafeState(Exception): pass
class OperationFailure(Exception): pass
OPEN_DIR = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
def checked_path(value, reject_root=False):
    if (not value or not os.path.isabs(value) or any(ord(char) < 32 or ord(char) == 127 for char in value)
            or any(part in (".", "..") for part in value.split("/"))):
        raise UnsafeState
    value = os.path.normpath(value)
    if reject_root and value == "/": raise UnsafeState
    return value
def path_error(exc):
    if isinstance(exc, (FileNotFoundError, NotADirectoryError)) or getattr(exc, "errno", None) == errno.ELOOP: raise UnsafeState from exc
    raise OperationFailure from exc
def managed_open_error(exc):
    if getattr(exc, "errno", None) in (errno.ELOOP, errno.ENOTDIR): raise UnsafeState from exc
    raise OperationFailure from exc
def physical_dir(value):
    try:
        value = str(pathlib.Path(value).resolve(strict=True)); info = os.stat(value, follow_symlinks=False)
    except RuntimeError as exc: raise UnsafeState from exc
    except OSError as exc:
        path_error(exc)
    if not stat.S_ISDIR(info.st_mode): raise UnsafeState
    return value
def select_root():
    if "HARNESS_STATE_ROOT" in os.environ:
        root = checked_path(os.environ["HARNESS_STATE_ROOT"], True); parent, leaf = os.path.split(root)
        return physical_dir(parent), leaf
    base = os.environ["XDG_RUNTIME_DIR"] if "XDG_RUNTIME_DIR" in os.environ else os.environ.get("TMPDIR") or "/tmp"
    return physical_dir(checked_path(base)), f"aosp-harness-{os.geteuid()}"
def identity(info): return info.st_dev, info.st_ino, stat.S_IFMT(info.st_mode)
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
            try:
                before = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
            except OSError as exc:
                raise OperationFailure from exc
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
    if not stat.S_ISDIR(before.st_mode): raise UnsafeState
    child_fd = None
    try:
        child_fd = os.open(name, OPEN_DIR, dir_fd=parent_fd); current = os.fstat(child_fd)
    except OSError as exc:
        if child_fd is not None: os.close(child_fd)
        managed_open_error(exc)
    expected_euid = os.geteuid()  # HARNESS_TEST_MARKER_EXPECTED_EUID
    if (identity(before) != identity(current) or current.st_uid != expected_euid
            or stat.S_IMODE(current.st_mode) != 0o700):
        os.close(child_fd); raise UnsafeState
    try:
        after = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
    except OSError as exc:
        os.close(child_fd); raise OperationFailure from exc
    if identity(after) != identity(current): os.close(child_fd); raise UnsafeState
    return child_fd
def dispatch(project, session):
    parent, root = select_root()
    fds = []
    try:
        pass  # HARNESS_TEST_MARKER_OS_ERROR
        try:
            fds.append(os.open(parent, OPEN_DIR))
        except OSError as exc:
            path_error(exc)
        for name in (root, project, session):
            fds.append(open_managed(fds[-1], name))
        return os.path.join(parent, root, project, session)
    finally:
        for child_fd in reversed(fds): os.close(child_fd)
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
fi
