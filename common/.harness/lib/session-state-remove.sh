#!/usr/bin/env bash
# session-state-remove.sh -- private non-creating verified remove module.
# Guard: active only when the 03c signals export
# _harness_session_write_with_signals exists; otherwise inert (source rc0,
# both streams empty, nothing defined, no file I/O). Active: defines one
# private export, _harness_session_remove_core <project-id> <session-id> --
# non-creating verified remove of the feature rule file, then bottom-up
# prune of safe empty session/project/root behind held-fd identity checks;
# success/missing 0, OS error 1, unsafe 2, stdout always empty.

declare -F _harness_session_write_with_signals >/dev/null || return 0 2>/dev/null || exit 0
_harness_session_remove_core() (
  if [[ $# != 2 ]] || ! _harness_component_is_safe "$1" || ! _harness_component_is_safe "$2"; then
    printf '%s\n' 'error: unsafe session state' >&2
    return 2
  fi
  umask 077
  python3 - "$1" "$2" <<'PY'
import errno, os, pathlib, stat, sys
UnsafeState, OperationFailure, Missing = (type(name, (Exception,), {}) for name in ("UnsafeState", "OperationFailure", "Missing"))
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
def physical_dir(value):
    try:
        value = str(pathlib.Path(value).resolve(strict=True)); info = os.stat(value, follow_symlinks=False)
    except RuntimeError as exc: raise UnsafeState from exc
    except OSError as exc: path_error(exc)
    if not stat.S_ISDIR(info.st_mode): raise UnsafeState
    return value
def select_root():
    if "HARNESS_STATE_ROOT" in os.environ:
        root = checked_path(os.environ["HARNESS_STATE_ROOT"], True); parent, leaf = os.path.split(root)
        return physical_dir(parent), leaf
    base = os.environ["XDG_RUNTIME_DIR"] if "XDG_RUNTIME_DIR" in os.environ else os.environ.get("TMPDIR") or "/tmp"
    return physical_dir(checked_path(base)), f"aosp-harness-{os.geteuid()}"
def identity(info): return info.st_dev, info.st_ino, stat.S_IFMT(info.st_mode)
def open_verified(parent_fd, name):
    try:
        before = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
    except FileNotFoundError as exc: raise Missing from exc
    except OSError as exc: path_error(exc)
    if not stat.S_ISDIR(before.st_mode): raise UnsafeState
    child_fd = None
    try:
        child_fd = os.open(name, OPEN_DIR, dir_fd=parent_fd); current = os.fstat(child_fd)
    except OSError as exc:
        if child_fd is not None: os.close(child_fd)
        if isinstance(exc, FileNotFoundError): raise Missing from exc
        if getattr(exc, "errno", None) in (errno.ELOOP, errno.ENOTDIR): raise UnsafeState from exc
        raise OperationFailure from exc
    if identity(before) != identity(current) or current.st_uid != os.geteuid() or stat.S_IMODE(current.st_mode) != 0o700:
        os.close(child_fd); raise UnsafeState
    try:
        after = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
    except OSError as exc: os.close(child_fd); raise OperationFailure from exc
    if identity(after) != identity(current): os.close(child_fd); raise UnsafeState
    return child_fd
def remove_feature(session_fd):
    try:
        info = os.stat("feature", dir_fd=session_fd, follow_symlinks=False)
    except FileNotFoundError: return
    except OSError as exc: path_error(exc)
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1:
        raise UnsafeState
    try:
        os.unlink("feature", dir_fd=session_fd)
    except FileNotFoundError: pass
    except OSError as exc: raise OperationFailure from exc
def dispatch(project, session):
    parent, root = select_root(); fds = []
    try:
        pass  # HARNESS_TEST_MARKER_OS_ERROR
        try:
            fds.append(os.open(parent, OPEN_DIR))
        except OSError as exc: path_error(exc)
        for name in (root, project, session):
            fds.append(open_verified(fds[-1], name))
        remove_feature(fds[3])
        for parent_fd, child_fd, name in ((fds[2], fds[3], session), (fds[1], fds[2], project), (fds[0], fds[1], root)):
            pass  # PRUNE_BEFORE_IDENTITY
            try:
                current = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
            except FileNotFoundError: break
            except OSError as exc: raise OperationFailure from exc
            if identity(current) != identity(os.fstat(child_fd)): raise UnsafeState
            try:
                os.rmdir(name, dir_fd=parent_fd)
            except OSError as exc:
                if getattr(exc, "errno", None) in (errno.ENOENT, errno.ENOTEMPTY): break
                raise OperationFailure from exc
    finally:
        for fd in reversed(fds): os.close(fd)
try:
    dispatch(sys.argv[1], sys.argv[2])
except Missing: pass
except UnsafeState:
    print("error: unsafe session state", file=sys.stderr); raise SystemExit(2)
except (OSError, OperationFailure):
    print("error: session state operation failed", file=sys.stderr); raise SystemExit(1)
PY
)
