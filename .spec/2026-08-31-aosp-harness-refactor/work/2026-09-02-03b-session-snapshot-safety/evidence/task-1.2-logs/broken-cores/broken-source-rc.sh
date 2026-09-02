#!/usr/bin/env bash
if declare -F harness_validate_feature_name >/dev/null \
  && declare -F _harness_session_path_core >/dev/null; then
  _harness_session_snapshot_worker() {
    _harness_snapshot_exec() {
      exec python3 - "$@" <<'PY'
import ctypes, errno, os, re, secrets, signal, stat, sys
Unsafe, Missing, Failed, Interrupted = (type(name, (Exception,), {}) for name in ("Unsafe", "Missing", "Failed", "Interrupted"))
OPEN_DIR = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC; OPEN_FILE = os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC
VALID = re.compile(br"[A-Za-z0-9][A-Za-z0-9._-]{0,127}\n\Z")
def ident(info): return info.st_dev, info.st_ino, stat.S_IFMT(info.st_mode)
def close_all(fds):
    error = None
    for fd in fds:
        try: os.close(fd)
        except (OSError, Interrupted) as exc: error = error or exc
    if first_signal[0] is not None: raise Interrupted
    if error is not None: raise error
def managed_euid():
    return os.geteuid()  # HARNESS_TEST_MARKER_MANAGED_EXPECTED_EUID
def snapshot_euid():
    return os.geteuid()  # HARNESS_TEST_MARKER_SNAPSHOT_EXPECTED_EUID
def verify(info, kind, owner, mode, links=None):
    good_type = stat.S_ISDIR(info.st_mode) if kind == "dir" else stat.S_ISREG(info.st_mode)
    if (not good_type or info.st_uid != owner or stat.S_IMODE(info.st_mode) != mode
            or (links is not None and info.st_nlink != links)):
        raise Unsafe
def managed_checkpoint(parent_fd, name):
    pass  # HARNESS_TEST_MARKER_SNAPSHOT_MANAGED_BEFORE_OPEN
def open_dir(parent_fd, name):
    try:
        before = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
    except FileNotFoundError as exc:
        raise Failed from exc
    except OSError as exc:
        raise Failed from exc
    verify(before, "dir", managed_euid(), 0o700)
    managed_checkpoint(parent_fd, name)
    fd = None
    try:
        fd = os.open(name, OPEN_DIR, dir_fd=parent_fd)
        current = os.fstat(fd)
        after = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
    except OSError as exc:
        if fd is not None: os.close(fd)
        if getattr(exc, "errno", None) in (errno.ELOOP, errno.ENOTDIR): raise Unsafe from exc
        raise Failed from exc
    verify(current, "dir", managed_euid(), 0o700)
    verify(after, "dir", managed_euid(), 0o700)
    if ident(before) != ident(current) or ident(after) != ident(current):
        os.close(fd)
        raise Unsafe
    return fd
def open_session(path, project, session):
    parts = path.rsplit(os.sep, 3)
    if len(parts) != 4 or parts[2:] != [project, session] or not parts[1]: raise Unsafe
    try:
        fds = [os.open(parts[0] or os.sep, OPEN_DIR)]
    except OSError as exc:
        raise Failed from exc
    try:
        for name in parts[1:]: fds.append(open_dir(fds[-1], name))
        return fds[-1], fds[:-1]
    except Exception:
        close_all(reversed(fds))
        raise
def snapshot_checkpoint(dir_fd):
    pass  # HARNESS_TEST_MARKER_SNAPSHOT_BEFORE_OPEN
def read_bytes(fd):
    chunks, total = [], 0
    while total < 130:
        chunk = os.read(fd, 130 - total)
        if not chunk: break
        chunks.append(chunk)
        total += len(chunk)
    if total == 130: raise Unsafe
    return b"".join(chunks)
def read_snapshot(dir_fd):
    try:
        before = os.stat("feature", dir_fd=dir_fd, follow_symlinks=False)
    except FileNotFoundError as exc:
        raise Missing from exc
    except OSError as exc:
        raise Failed from exc
    verify(before, "file", snapshot_euid(), 0o600, 1)
    snapshot_checkpoint(dir_fd)
    fd = None
    try:
        fd = os.open("feature", OPEN_FILE, dir_fd=dir_fd)
        current = os.fstat(fd)
        after = os.stat("feature", dir_fd=dir_fd, follow_symlinks=False)
    except OSError as exc:
        if fd is not None: os.close(fd)
        if getattr(exc, "errno", None) in (errno.ELOOP, errno.ENOTDIR): raise Unsafe from exc
        raise Failed from exc
    try:
        verify(current, "file", snapshot_euid(), 0o600, 1)
        verify(after, "file", snapshot_euid(), 0o600, 1)
        if ident(before) != ident(current) or ident(after) != ident(current): raise Unsafe
        data = read_bytes(fd)
    finally:
        close_all((fd,))
    if not VALID.fullmatch(data): raise Unsafe
    return data[:-1].decode("ascii")
def temp_checkpoint(dir_fd, temp):
    pass  # HARNESS_TEST_MARKER_TEMP_BEFORE_PUBLISH
def publish_errno(dir_fd, temp):
    pass  # HARNESS_TEST_MARKER_PUBLISH_RESULT
    try:
        call = getattr(ctypes.CDLL(None, use_errno=True), "renameat2")
    except AttributeError as exc:
        raise Failed from exc
    if call(dir_fd, temp.encode(), dir_fd, b"feature", 1) == 0: return 0
    return ctypes.get_errno()
def publish(dir_fd, feature):
    try:
        current = read_snapshot(dir_fd)
        return 0 if current == feature else 3
    except Missing:
        pass
    temp = ".snapshot-" + secrets.token_hex(16)
    temp_fd = None
    try:
        temp_fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL
                          | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600, dir_fd=dir_fd)
        verify(os.fstat(temp_fd), "file", os.geteuid(), 0o600, 1)
        data = (feature + "\n").encode("ascii")
        while data: data = data[os.write(temp_fd, data):]
        owned_fd, temp_fd = temp_fd, None
        os.close(owned_fd)
        temp_checkpoint(dir_fd, temp)
        result = publish_errno(dir_fd, temp)
        if result == 0:
            temp = None
            return 0
        if result != errno.EEXIST: raise Failed
        os.unlink(temp, dir_fd=dir_fd); temp = None
        try:
            current = read_snapshot(dir_fd)
        except Missing as exc:
            raise Failed from exc
        return 0 if current == feature else 3
    finally:
        try:
            if temp_fd is not None: close_all((temp_fd,))
        finally:
            if temp is not None:
                try: os.unlink(temp, dir_fd=dir_fd)
                except OSError as exc:
                    if not isinstance(exc, FileNotFoundError) and first_signal[0] is None: raise
def path_from_fd(fd):
    info = os.fstat(fd)
    verify(info, "file", os.geteuid(), 0o600, 0)
    os.lseek(fd, 0, os.SEEK_SET)
    raw = os.read(fd, 4097)
    if len(raw) == 4097 or raw.count(b"\n") != 1 or not raw.endswith(b"\n"): raise Unsafe
    return os.fsdecode(raw[:-1])
def os_checkpoint():
    pass  # HARNESS_TEST_MARKER_OS_ERROR
def dispatch(op, path_fd, project, session, feature):
    path = path_from_fd(int(path_fd))
    os_checkpoint()
    session_fd, ancestors = open_session(path, project, session)
    try:
        if op == "write": return publish(session_fd, feature)
        if op != "read": raise Unsafe
        print(read_snapshot(session_fd)); return 0
    finally:
        close_all([session_fd] + list(reversed(ancestors)))
SIGNALS = (signal.SIGHUP, signal.SIGINT, signal.SIGTERM); first_signal = [None]
def on_signal(number, frame):
    if first_signal[0] is not None: return
    first_signal[0] = number
    for item in SIGNALS: signal.signal(item, signal.SIG_IGN)
    raise Interrupted
try:
    if sys.argv[1] == "write":
        for number in SIGNALS:
            signal.signal(number, on_signal)
    raise SystemExit(dispatch(*sys.argv[1:]))
except Interrupted: raise SystemExit(128 + first_signal[0])
except Missing: raise SystemExit(3)
except Unsafe: raise SystemExit(2)
except (OSError, Failed, AttributeError): raise SystemExit(128 + first_signal[0] if first_signal[0] is not None else 1)
PY
    }
    _harness_snapshot_dispatch() {
      [[ ($# == 3 && $1 == read) || ($# == 4 && $1 == write) ]] || return 2
      local op=$1 project=$2 session=$3 feature=${4-} path_file path_fd rc
      if [[ $op == write ]] && ! harness_validate_feature_name "$feature" >/dev/null 2>&1; then return 2; fi
      umask 077
      path_file=$(mktemp "${TMPDIR:-/tmp}/snapshot-path.XXXXXXXX" 2>/dev/null) || return 1
      { exec {path_fd}<>"$path_file"; } 2>/dev/null || {
        rm -f -- "$path_file" 2>/dev/null
        return 1
      }
      rm -f -- "$path_file" 2>/dev/null || return 1
      : # HARNESS_TEST_MARKER_CAPTURE_READY
      _harness_session_path_core "$project" "$session" 2>/dev/null 1>&"$path_fd"
      rc=$?
      ((rc == 0)) || return "$rc"
      _harness_snapshot_exec "$op" "$path_fd" "$project" "$session" "$feature"
    }
    _harness_snapshot_dispatch "$@"
  }
  _harness_session_snapshot_write_core() (_harness_session_snapshot_worker write "$@")
  _harness_session_snapshot_read_core() (_harness_session_snapshot_worker read "$@")
fi

return 1
