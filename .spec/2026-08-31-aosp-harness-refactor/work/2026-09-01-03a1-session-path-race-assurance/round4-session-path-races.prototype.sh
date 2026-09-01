#!/usr/bin/env bash
# THROWAWAY ROUND4 PROTOTYPE: proves anchor-first 03a1 dispatch and race shape.
set -u
ROOT=${HARNESS_PROTOTYPE_ROOT:-/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a-session-path-safety}
FOUNDATION="$ROOT/common/.harness/lib/session-state-foundation.sh"
PROVIDER="$ROOT/common/.harness/lib/session-state-path.sh"
TMP_TEST=$(mktemp -d "${TMPDIR:-/tmp}/session-path-races-round4.XXXXXX")
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
inert() {
  PROVIDER=$PROVIDER bash <<'SH'
set -u
unset HARNESS_SESSION_STATE_PROVIDER_VERSION
unset -f harness_validate_feature_name _harness_session_state_foundation_path _harness_session_state_run \
  _harness_session_path_core harness_session_state_path harness_session_state_write \
  harness_session_state_read harness_session_state_remove 2>/dev/null || :
[[ ! -f $PROVIDER ]] || source "$PROVIDER"
! declare -F _harness_session_path_core >/dev/null || exit 1
for name in harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove; do
  ! declare -F "$name" >/dev/null || exit 1
done
[[ ! -v HARNESS_SESSION_STATE_PROVIDER_VERSION ]]
SH
}
core_available() {
  [[ -f $PROVIDER && -f $FOUNDATION ]] \
    && bash -c 'source "$1"; source "$2"; declare -F _harness_session_path_core >/dev/null' \
      _ "$FOUNDATION" "$PROVIDER" >/dev/null 2>&1
}
validate_provider_anchors() {
  local marker count
  for marker in HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN HARNESS_TEST_MARKER_EXPECTED_EUID HARNESS_TEST_MARKER_OS_ERROR; do
    count=$(grep -Fo "$marker" "$PROVIDER" | wc -l)
    [[ $count == 1 ]] || return 1
  done
}
if [[ -f $PROVIDER ]] && ! validate_provider_anchors; then
  fail 'provider anchors: expected each exactly once'
fi
if [[ $GROUP == dependency-absent ]] || ! core_available; then
  inert || fail 'dependency absent: inert surface'
  printf '%s\n' "$SUMMARY"
  exit 0
fi
CASE_LOG=${HARNESS_PROTOTYPE_CASE_LOG:-$TMP_TEST/cases.log}
python3 - "$FOUNDATION" "$PROVIDER" "$TMP_TEST" "$CASE_LOG" <<'PY'
import hashlib
import os
import pathlib
import stat
import subprocess
import sys

foundation, provider, workspace, case_log = map(pathlib.Path, sys.argv[1:])
unsafe = (2, b"", b"error: unsafe session state\n")
operation = (1, b"", b"error: session state operation failed\n")
markers = {
    "MANAGED": "HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN",
    "EXPECTED_EUID": "HARNESS_TEST_MARKER_EXPECTED_EUID",
    "OS_ERROR": "HARNESS_TEST_MARKER_OS_ERROR",
}
source = provider.read_text()
source_bytes = provider.read_bytes()
managed_hook = r'''    _kind, _layer, _expected_name, _detail, _hook = os.environ["HARNESS_RACE_PLAN"].split("|", 4)
    _match = ((_kind == "swap" and phase == "before_open" and not made)
              or (_kind == "eexist" and phase in ("before_mkdir", "after_eexist"))
              or (_kind in ("mkdir-replace", "post-mkdir-disappear") and phase == "before_open" and made)
              or (_kind == "mkdir-failure" and phase == "before_mkdir" and not made)
              or (_kind in ("open-disappear", "final-stat-disappear") and phase == "before_open" and not made))
    if name == _expected_name and _match:
        _catch = "1" if phase == "after_eexist" else "0"
        with open(_hook, "a") as _stream:
            _stream.write(f"MANAGED|{_layer}|{name}|{phase}|{int(made)}|{_catch}\n")
        if _kind == "swap" and phase == "before_open" and not made:
            os.rename(name, name+".old", src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
            if _detail == "safe-dir": os.mkdir(name, 0o700, dir_fd=parent_fd)
            elif _detail == "link": os.symlink(name+".old", name, dir_fd=parent_fd)
            else: os.close(os.open(name, os.O_CREAT | os.O_WRONLY, 0o600, dir_fd=parent_fd))
        elif _kind == "eexist" and phase == "before_mkdir":
            os.mkdir(name, 0o700, dir_fd=parent_fd)
            if _detail == "unsafe": os.chmod(name, 0o755, dir_fd=parent_fd)
        elif _kind == "eexist" and phase == "after_eexist" and _detail == "disappear":
            os.rmdir(name, dir_fd=parent_fd)
        elif _kind == "mkdir-replace" and phase == "before_open" and made:
            os.rename(name, name+".old", src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
            os.mkdir(name, 0o700, dir_fd=parent_fd); os.chmod(name, 0o755, dir_fd=parent_fd)
        elif _kind == "mkdir-failure" and phase == "before_mkdir":
            _real_mkdir = os.mkdir
            def _planned_mkdir(path, mode=0o777, *, dir_fd=None):
                if path != name: return _real_mkdir(path, mode, dir_fd=dir_fd)
                raise FileNotFoundError(errno.ENOENT, "gone")
            os.mkdir = _planned_mkdir
        elif _kind == "post-mkdir-disappear" and phase == "before_open" and made:
            os.rmdir(name, dir_fd=parent_fd)
        elif _kind == "open-disappear" and phase == "before_open" and not made:
            os.rmdir(name, dir_fd=parent_fd)
        elif _kind == "final-stat-disappear" and phase == "before_open" and not made:
            _real_stat = os.stat
            def _planned_stat(path, *args, **kwargs):
                if path == name and kwargs.get("dir_fd") == parent_fd:
                    os.stat = _real_stat; os.rmdir(name, dir_fd=parent_fd)
                return _real_stat(path, *args, **kwargs)
            os.stat = _planned_stat
        pass  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN'''
euid_hook = r'''    _kind, _layer, _expected_name, _detail, _hook = os.environ["HARNESS_RACE_PLAN"].split("|", 4)
    if _kind == "wrong-euid" and name == _expected_name:
        with open(_hook, "a") as _stream:
            _stream.write(f"EXPECTED_EUID|{_layer}|{name}|N/A|{int(made)}|0\n")
    expected_euid = os.geteuid() + int(_kind == "wrong-euid" and name == _expected_name)  # HARNESS_TEST_MARKER_EXPECTED_EUID'''
os_hook = r'''        _kind, _layer, _expected_name, _detail, _hook = os.environ["HARNESS_RACE_PLAN"].split("|", 4)
        with open(_hook, "a") as _stream:
            _stream.write("OS_ERROR|N/A|N/A|N/A|N/A|N/A\n")
        raise OSError(errno.EIO)  # HARNESS_TEST_MARKER_OS_ERROR'''


def check(condition, label):
    if not condition:
        raise AssertionError(label)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def signature(path):
    info = path.lstat()
    kind = "link" if path.is_symlink() else "dir" if stat.S_ISDIR(info.st_mode) else "file"
    target = os.readlink(path) if kind == "link" else "-"
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


def injected_copy(base, anchor):
    marker = markers[anchor]
    replacement = {"MANAGED": managed_hook, "EXPECTED_EUID": euid_hook, "OS_ERROR": os_hook}[anchor]
    check(all(source.count(item) == 1 for item in markers.values()), "source anchor counts")
    lines = source.splitlines(keepends=True)
    indexes = [index for index, line in enumerate(lines) if marker in line]
    check(len(indexes) == 1, f"anchor line {anchor}")
    original = lines[indexes[0]]
    lines[indexes[0]] = replacement + "\n"
    expected = source.replace(original, replacement + "\n")
    copy = base / "provider.sh"
    copy.write_text("".join(lines))
    check(copy.read_text() == expected, f"strict replacement {anchor}")
    check(all(copy.read_text().count(item) == 1 for item in markers.values()), "copy anchor counts")
    return copy, hashlib.sha256(source.encode()).hexdigest()


def make_parents(base, layer, include_target=True):
    root, target = base / "state", base / "state"
    if layer != "root":
        root.mkdir(mode=0o700); target = root / "project"
    if layer == "session":
        target.mkdir(mode=0o700); target = target / "session"
    if include_target: target.mkdir(mode=0o700)
    return root, target


def invoke(copy, root, plan):
    environment = os.environ.copy()
    environment.pop("XDG_RUNTIME_DIR", None); environment.pop("TMPDIR", None)
    environment["HARNESS_STATE_ROOT"] = str(root)
    environment["HARNESS_RACE_PLAN"] = "|".join(plan)
    return subprocess.run(
        ["bash", "-c", 'source "$1"; source "$2"; _harness_session_path_core "$3" "$4"', "_", str(foundation), str(copy), "project", "session"],
        env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )


def expect(label, result, expected, hook, hook_lines):
    check((result.returncode, result.stdout, result.stderr) == expected, f"{label}: protocol")
    actual_hooks = hook.read_text().splitlines()
    check(actual_hooks == hook_lines, f"{label}: hook signature {actual_hooks!r}")
    with case_log.open("a") as stream: stream.write(label + "\n")


def setup(label, layer, include_target=True, anchor="MANAGED"):
    base = workspace / label; base.mkdir()
    root, target = make_parents(base, layer, include_target)
    hook = workspace / f"{label}.hook"
    copy, provider_hash = injected_copy(base, anchor)
    plan = [label.split("-", 1)[0], layer, target.name, label, str(hook)]
    return base, root, target, hook, copy, provider_hash, plan


for layer in ("root", "project", "session"):
    for kind in ("safe-dir", "link", "file"):
        label = f"swap-{layer}-{kind}"
        base, root, target, hook, copy, provider_hash, plan = setup(label, layer)
        plan[0], plan[3] = "swap", kind
        victim = target / "victim"; victim.write_text("sentinel")
        old_target, old_victim = signature(target), signature(victim)
        expect(label, invoke(copy, root, plan), unsafe, hook, [f"MANAGED|{layer}|{target.name}|before_open|0|0"])
        old, replacement = target.with_name(target.name + ".old"), signature(target)
        check(signature(old) == old_target and signature(old / "victim") == old_victim, f"{label}: victim")
        check(replacement[0] == {"safe-dir": "dir", "link": "link", "file": "file"}[kind], f"{label}: type")
        check(replacement[2] != old_target[2] and digest(copy) != provider_hash, f"{label}: identity/copy")
        if kind == "link": check(replacement[5] == target.name + ".old", f"{label}: readlink target")
        allowed = {"provider.sh", str(target.relative_to(base)), str(old.relative_to(base)), str((old / "victim").relative_to(base))}
        parent = target.parent
        while parent != base: allowed.add(str(parent.relative_to(base))); parent = parent.parent
        check(set(inventory(base)) == allowed, f"{label}: inventory")


def eexist(layer, kind):
    label = f"eexist-{layer}-{kind}"
    base, root, target, hook, copy, _, plan = setup(label, layer, False)
    plan[0], plan[3] = "eexist", kind
    expected = (0, f"{root}/project/session\n".encode(), b"") if kind == "safe" else unsafe if kind == "unsafe" else operation
    hooks = [f"MANAGED|{layer}|{target.name}|before_mkdir|0|0", f"MANAGED|{layer}|{target.name}|after_eexist|0|1"]
    expect(label, invoke(copy, root, plan), expected, hook, hooks)
    if kind == "unsafe": check(signature(target)[3] == 0o755, f"{label}: unsafe winner")
    if kind == "disappear": check(not target.exists(), f"{label}: disappeared winner")


eexist("root", "safe")
eexist("project", "unsafe")
eexist("session", "disappear")


def managed_case(kind, layer, include_target, expected, expected_hooks):
    label = f"{kind}-{layer}"
    base, root, target, hook, copy, _, plan = setup(label, layer, include_target)
    plan[0] = kind
    expect(label, invoke(copy, root, plan), expected, hook, expected_hooks(target.name))
    return base, target


base, target = managed_case("mkdir-replace", "root", False, unsafe, lambda name: [f"MANAGED|root|{name}|before_open|1|0"])
check(signature(target.with_name("state.old"))[3] == 0o700 and signature(target)[3] == 0o755, "mkdir replacement")

label = "wrong-euid-project"
base, root, target, hook, copy, _, plan = setup(label, "project", True, "EXPECTED_EUID")
plan[0] = "wrong-euid"
expect(label, invoke(copy, root, plan), unsafe, hook, ["EXPECTED_EUID|project|project|N/A|0|0"])
check(not (target / "session").exists(), "wrong EUID traversal")

managed_case("mkdir-failure", "project", False, operation, lambda name: [f"MANAGED|project|{name}|before_mkdir|0|0"])
managed_case("post-mkdir-disappear", "session", False, operation, lambda name: [f"MANAGED|session|{name}|before_open|1|0"])
managed_case("open-disappear", "root", True, operation, lambda name: [f"MANAGED|root|{name}|before_open|0|0"])
managed_case("final-stat-disappear", "session", True, operation, lambda name: [f"MANAGED|session|{name}|before_open|0|0"])

label = "real-eio"
base = workspace / label; base.mkdir(); hook = workspace / f"{label}.hook"
copy, _ = injected_copy(base, "OS_ERROR")
plan = [label, "N/A", "N/A", "N/A", str(hook)]
expect(label, invoke(copy, base / "state", plan), operation, hook, ["OS_ERROR|N/A|N/A|N/A|N/A|N/A"])
check(not (base / "state").exists(), "EIO created root")
case_ids = case_log.read_text().splitlines()
check(len(case_ids) == 19 and len(set(case_ids)) == 19, "exact unique case count")
check(provider.read_bytes() == source_bytes, "production provider changed")
PY
[[ $? == 0 ]] || fail 'race driver'
printf '%s\n' "$SUMMARY"
