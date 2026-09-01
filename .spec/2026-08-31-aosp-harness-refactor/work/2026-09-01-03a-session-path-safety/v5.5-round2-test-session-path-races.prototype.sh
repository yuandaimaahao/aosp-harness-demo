#!/usr/bin/env bash
set -u
ROOT=${HARNESS_PROTOTYPE_ROOT:-/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a-session-path-safety}
FOUNDATION="$ROOT/common/.harness/lib/session-state-foundation.sh"
PROVIDER="$ROOT/common/.harness/lib/session-state-path.sh"
TMP_TEST=$(mktemp -d "${TMPDIR:-/tmp}/session-path-races-prototype.XXXXXX")
trap 'rm -rf "$TMP_TEST"' EXIT
fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}
SUMMARY='RESULT PASS  session path race assurance'
case ${1:-all} in
  --dependency-absent)
    [[ $# == 1 ]] || fail 'option: dependency-absent takes no value'
    GROUP=dependency-absent
    ;;
  all)
    (($# <= 1)) || fail 'option: all takes no value'
    GROUP=all
    ;;
  *) fail "option: ${1:-empty} unsupported" ;;
esac
if [[ $GROUP == dependency-absent || ! -f $PROVIDER ]]; then
  FOUNDATION=$FOUNDATION bash <<'SH'
set -u
unset HARNESS_SESSION_STATE_PROVIDER_VERSION
unset -f _harness_session_path_core harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove 2>/dev/null || :
[[ ! -f $FOUNDATION ]] || source "$FOUNDATION"
! declare -F _harness_session_path_core >/dev/null || exit 1
for name in harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove; do
  ! declare -F "$name" >/dev/null || exit 1
done
[[ ! -v HARNESS_SESSION_STATE_PROVIDER_VERSION ]]
SH
  [[ $? == 0 ]] || fail 'dependency absent: inert surface'
  printf '%s\n' "$SUMMARY"
  exit 0
fi
[[ -f $FOUNDATION ]] || fail 'source present: foundation missing'
CASE_LOG=${HARNESS_PROTOTYPE_CASE_LOG:-$TMP_TEST/cases.log}
python3 - "$FOUNDATION" "$PROVIDER" "$TMP_TEST" "$CASE_LOG" <<'PY'
import hashlib
import os
import pathlib
import stat
import subprocess
import sys

foundation = pathlib.Path(sys.argv[1])
provider = pathlib.Path(sys.argv[2])
workspace = pathlib.Path(sys.argv[3])
case_log = pathlib.Path(sys.argv[4])
unsafe = (2, b"", b"error: unsafe session state\n")
operation = (1, b"", b"error: session state operation failed\n")
anchors = (
    "HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN",
    "HARNESS_TEST_MARKER_EXPECTED_EUID",
    "HARNESS_TEST_MARKER_OS_ERROR",
)
managed = "    pass  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
catch_line = "            pass  # provider-copy catch sentinel is injected here"


def check(condition, label):
    if not condition:
        raise AssertionError(label)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def signature(path):
    info = path.lstat()
    kind = "link" if path.is_symlink() else "dir" if stat.S_ISDIR(info.st_mode) else "file"
    target = os.readlink(path) if path.is_symlink() else "-"
    content = digest(path) if kind == "file" else "-"
    return kind, info.st_dev, info.st_ino, stat.S_IMODE(info.st_mode), info.st_uid, target, content


def inventory(root):
    found = {}
    for current, directories, files in os.walk(root, followlinks=False):
        current_path = pathlib.Path(current)
        for name in directories + files:
            path = current_path / name
            found[str(path.relative_to(root))] = signature(path)
    return found


def copy_provider(base):
    copy = base / "provider.sh"
    text = provider.read_text()
    for marker in anchors:
        check(text.count(marker) == 1, f"anchor count {marker}")
    copy.write_text(text)
    return copy, digest(copy)


def replace_once(copy, needle, replacement):
    text = copy.read_text()
    check(text.count(needle) == 1, f"replace count {needle!r}")
    copy.write_text(text.replace(needle, replacement))


def invoke(copy, root):
    environment = os.environ.copy()
    environment.pop("XDG_RUNTIME_DIR", None)
    environment.pop("TMPDIR", None)
    environment["HARNESS_STATE_ROOT"] = str(root)
    return subprocess.run(
        ["bash", "-c", 'source "$1"; source "$2"; _harness_session_path_core "$3" "$4"', "_", str(foundation), str(copy), "project", "session"],
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def expect(label, result, expected):
    actual = result.returncode, result.stdout, result.stderr
    check(actual == expected, f"{label}: protocol {actual!r}")
    with case_log.open("a") as stream:
        stream.write(label + "\n")


def make_parents(base, layer, include_target=True):
    root = base / "state"
    target = root
    if layer != "root":
        root.mkdir(mode=0o700)
        target = root / "project"
    if layer == "session":
        target.mkdir(mode=0o700)
        target = target / "session"
    if include_target:
        target.mkdir(mode=0o700)
    return root, target


def assert_keys(base, expected, label):
    check(set(inventory(base)) == set(expected), f"{label}: inventory keys {set(inventory(base))!r}")


for layer in ("root", "project", "session"):
    for kind in ("safe-dir", "link", "file"):
        label = f"swap-{layer}-{kind}"
        base = workspace / label
        base.mkdir()
        root, target = make_parents(base, layer)
        victim = target / "victim"
        victim.write_text("sentinel")
        old_target = signature(target)
        old_victim = signature(victim)
        copy, provider_hash = copy_provider(base)
        hit = base / "hit"
        name = target.name
        if kind == "safe-dir":
            action = "os.mkdir(name, 0o700, dir_fd=parent_fd)"
        elif kind == "link":
            action = "os.symlink(name+'.old', name, dir_fd=parent_fd)"
        else:
            action = "os.close(os.open(name, os.O_CREAT|os.O_WRONLY, 0o600, dir_fd=parent_fd))"
        injection = f"    if phase == 'before_open' and name == '{name}' and not made: os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); {action}; pathlib.Path('{hit}').touch()  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
        replace_once(copy, managed, injection)
        expect(label, invoke(copy, root), unsafe)
        old = target.with_name(target.name + ".old")
        check(signature(old) == old_target and signature(old / "victim") == old_victim, f"{label}: victim signature")
        replacement = signature(target)
        expected_kind = {"safe-dir": "dir", "link": "link", "file": "file"}[kind]
        check(replacement[0] == expected_kind and replacement[2] != old_target[2], f"{label}: replacement identity/type")
        check(digest(copy) != provider_hash and signature(hit)[0] == "file", f"{label}: injection/provider copy")
        ancestors = set()
        parent = target.parent
        while parent != base:
            ancestors.add(str(parent.relative_to(base)))
            parent = parent.parent
        expected_paths = ancestors | {"provider.sh", "hit", str(target.relative_to(base)), str(old.relative_to(base)), str((old / "victim").relative_to(base))}
        assert_keys(base, expected_paths, label)


def eexist_case(layer, kind):
    label = f"eexist-{layer}-{kind}"
    base = workspace / label
    base.mkdir()
    root, target = make_parents(base, layer, include_target=False)
    copy, _ = copy_provider(base)
    hit, caught = base / "hit", base / "caught"
    name = target.name
    mode = "0o755" if kind == "unsafe" else "0o700"
    chmod = "os.chmod(name, 0o755, dir_fd=parent_fd)" if kind == "unsafe" else "None"
    after = f"os.rmdir(name, dir_fd=parent_fd), pathlib.Path('{base / 'gone'}').touch()" if kind == "disappear" else "None"
    action = f"    if name == '{name}' and not made: (os.mkdir(name, {mode}, dir_fd=parent_fd), {chmod}, pathlib.Path('{hit}').touch()) if phase == 'before_mkdir' else ({after}) if phase == 'after_eexist' else None  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
    replace_once(copy, managed, action)
    replace_once(copy, catch_line, f"            pathlib.Path('{caught}').touch()  # provider-copy catch sentinel is injected here")
    expected = (0, f"{root}/project/session\n".encode(), b"") if kind == "safe" else unsafe if kind == "unsafe" else operation
    expect(label, invoke(copy, root), expected)
    check(hit.exists() and caught.exists(), f"{label}: made/catch")
    if kind == "unsafe":
        check(signature(target)[3] == 0o755 and not (target / "session").exists(), f"{label}: unsafe winner")
    if kind == "disappear":
        check(not target.exists() and (base / "gone").exists(), f"{label}: disappeared winner")


eexist_case("root", "safe")
eexist_case("project", "unsafe")
eexist_case("session", "disappear")

base = workspace / "mkdir-success-replace-root"
base.mkdir()
copy, _ = copy_provider(base)
hit = base / "hit"
injection = f"    if phase == 'before_open' and name == 'state' and made: os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.mkdir(name, 0o700, dir_fd=parent_fd); os.chmod(name, 0o755, dir_fd=parent_fd); pathlib.Path('{hit}').touch()  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
replace_once(copy, managed, injection)
expect("mkdir-success-replace-root", invoke(copy, base / "state"), unsafe)
check(signature(base / "state.old")[3] == 0o700 and signature(base / "state")[3] == 0o755 and hit.exists(), "mkdir replacement signatures")

base = workspace / "wrong-euid-project"
base.mkdir()
root, target = make_parents(base, "project")
copy, _ = copy_provider(base)
replace_once(copy, "    expected_euid = os.geteuid()  # HARNESS_TEST_MARKER_EXPECTED_EUID", "    expected_euid = os.geteuid() + (name == 'project')  # HARNESS_TEST_MARKER_EXPECTED_EUID")
expect("wrong-euid-project", invoke(copy, root), unsafe)
check(not (target / "session").exists(), "wrong EUID traversal")

base = workspace / "mkdir-failure-project"
base.mkdir()
root, _ = make_parents(base, "project", include_target=False)
copy, _ = copy_provider(base)
replace_once(copy, "            os.mkdir(name, 0o700, dir_fd=parent_fd)", "            raise FileNotFoundError(errno.ENOENT, 'gone') if name == 'project' else os.mkdir(name, 0o700, dir_fd=parent_fd)")
expect("mkdir-failure-project", invoke(copy, root), operation)

base = workspace / "post-mkdir-disappear-session"
base.mkdir()
root, _ = make_parents(base, "session", include_target=False)
copy, _ = copy_provider(base)
needle = "            made = True\n            try:\n                before = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)"
replacement = "            made = True\n            if name == 'session': os.rmdir(name, dir_fd=parent_fd)\n            try:\n                before = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)"
replace_once(copy, needle, replacement)
expect("post-mkdir-disappear-session", invoke(copy, root), operation)

base = workspace / "open-disappear-root"
base.mkdir()
root, target = make_parents(base, "root")
copy, _ = copy_provider(base)
hit = base / "hit"
replace_once(copy, managed, f"    if phase == 'before_open' and name == 'state' and not made: os.rmdir(name, dir_fd=parent_fd); pathlib.Path('{hit}').touch()  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN")
expect("open-disappear-root", invoke(copy, root), operation)
check(hit.exists() and not target.exists(), "open disappearance sentinel")

base = workspace / "final-stat-disappear-session"
base.mkdir()
root, _ = make_parents(base, "session")
copy, _ = copy_provider(base)
replace_once(copy, "        after = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)", "        os.rmdir(name, dir_fd=parent_fd) if name == 'session' else None; after = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)")
expect("final-stat-disappear-session", invoke(copy, root), operation)

base = workspace / "real-eio"
base.mkdir()
copy, _ = copy_provider(base)
replace_once(copy, "        pass  # HARNESS_TEST_MARKER_OS_ERROR", "        raise OSError(errno.EIO)  # HARNESS_TEST_MARKER_OS_ERROR")
expect("real-eio", invoke(copy, base / "state"), operation)
check(not (base / "state").exists(), "EIO created root")

check(len(case_log.read_text().splitlines()) == 19, "exact case count")
PY
[[ $? == 0 ]] || fail 'race driver'
printf '%s\n' "$SUMMARY"
