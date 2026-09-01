#!/usr/bin/env bash
# THROWAWAY ROUND6 PROTOTYPE: proves subtree rekey and all active oracles.
set -u
ROOT=${HARNESS_PROTOTYPE_ROOT:-/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a-session-path-safety}
FOUNDATION="$ROOT/common/.harness/lib/session-state-foundation.sh"
PROVIDER="$ROOT/common/.harness/lib/session-state-path.sh"
TMP_TEST=$(mktemp -d "${TMPDIR:-/tmp}/session-path-races-round6.XXXXXX")
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
self_disproofs = []
managed_hook = r'''    _kind, _layer, _expected_name, _detail, _hook = os.environ["HARNESS_RACE_PLAN"].split("|", 4)
    _match = ((_kind == "swap" and phase == "before_open" and not made)
              or (_kind == "eexist" and phase in ("before_mkdir", "after_eexist"))
              or (_kind in ("mkdir-replace", "post-mkdir-disappear") and phase == "before_open" and made)
              or (_kind == "mkdir-failure" and phase == "before_mkdir" and not made)
              or (_kind in ("open-disappear", "final-stat-disappear") and phase == "before_open" and not made))
    if name == _expected_name and _match:
        _catch = "1" if phase == "after_eexist" else "0"
        _original = ""
        if _kind == "mkdir-replace":
            _original_info = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
            _original = f"|original={'dir' if stat.S_ISDIR(_original_info.st_mode) else 'other'},{_original_info.st_dev},{_original_info.st_ino},{stat.S_IMODE(_original_info.st_mode)},{_original_info.st_uid}"
        with open(_hook, "a") as _stream:
            _stream.write(f"MANAGED|{_layer}|{name}|{phase}|{int(made)}|{_catch}{_original}\n")
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


def delta_schema(before, added=(), removed=(), changed=(), predicates=None):
    removed, changed = set(removed), set(changed)
    return {
        "paths_added": set(added), "paths_removed": removed,
        "protected": {path: value for path, value in before.items() if path not in removed | changed},
        "allowed_changed_paths": changed, "predicates": predicates or {},
    }


def assert_delta(before, after, schema, label):
    before_paths, after_paths = set(before), set(after)
    check(after_paths - before_paths == schema["paths_added"], f"{label}: paths added")
    check(before_paths - after_paths == schema["paths_removed"], f"{label}: paths removed")
    check(all(after.get(path) == value for path, value in schema["protected"].items()), f"{label}: protected signatures")
    changed = {path for path in before_paths & after_paths if before[path] != after[path]}
    check(changed == schema["allowed_changed_paths"], f"{label}: changed paths")
    check(all(path in after and predicate(before.get(path), after[path]) for path, predicate in schema["predicates"].items()), f"{label}: predicates")


def assert_hooks(actual, expected, label):
    check(actual == expected, f"{label}: ordered hooks {actual!r}")


def assert_marker_counts(text):
    check(all(text.count(item) == 1 for item in markers.values()), "source anchor counts")


def must_reject(callback, label):
    try: callback()
    except AssertionError: self_disproofs.append(label); return
    raise AssertionError(f"self-disproof accepted {label}")


def injected_copy(base, anchor):
    marker = markers[anchor]
    replacement = {"MANAGED": managed_hook, "EXPECTED_EUID": euid_hook, "OS_ERROR": os_hook}[anchor]
    assert_marker_counts(source)
    lines = source.splitlines(keepends=True)
    indexes = [index for index, line in enumerate(lines) if marker in line]
    check(len(indexes) == 1, f"anchor line {anchor}")
    original = lines[indexes[0]]
    lines[indexes[0]] = replacement + "\n"
    expected = source.replace(original, replacement + "\n", 1)
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


def exercise(label, copy, root, plan, expected, hook, hook_lines, base, schema_builder):
    before = inventory(base)
    result = invoke(copy, root, plan)
    after = inventory(base)
    check((result.returncode, result.stdout, result.stderr) == expected, f"{label}: protocol")
    actual_hooks = hook.read_text().splitlines()
    assert_hooks(actual_hooks, hook_lines(after) if callable(hook_lines) else hook_lines, label)
    schema = schema_builder(before)
    assert_delta(before, after, schema, label)
    with case_log.open("a") as stream: stream.write(label + "\n")
    return before, after, schema, actual_hooks


def setup(label, layer, include_target=True, anchor="MANAGED"):
    base = workspace / label; base.mkdir()
    root, target = make_parents(base, layer, include_target)
    hook = workspace / f"{label}.hook"
    copy, provider_hash = injected_copy(base, anchor)
    plan = [label.split("-", 1)[0], layer, target.name, label, str(hook)]
    return base, root, target, hook, copy, provider_hash, plan


def safe_dir(_, value):
    return value[0] == "dir" and value[3] == 0o700 and value[4] == os.geteuid()


def swap_delta(before, target, old, replacement_predicate):
    subtree = {path: value for path, value in before.items() if path == target or path.startswith(target + "/")}
    rekeyed = {old + path[len(target):]: value for path, value in subtree.items()}
    predicates = {path: (lambda _, value, expected=expected: value == expected) for path, expected in rekeyed.items()}
    predicates[target] = replacement_predicate
    return delta_schema(before, rekeyed, set(subtree) - {target}, (target,), predicates)


oracle_probes = {}
for layer in ("root", "project", "session"):
    for kind in ("safe-dir", "link", "file"):
        label = f"swap-{layer}-{kind}"
        base, root, target, hook, copy, provider_hash, plan = setup(label, layer)
        plan[0], plan[3] = "swap", kind
        victim = target / "victim"; victim.write_text("sentinel")
        old_target, old_victim = signature(target), signature(victim)
        old = target.with_name(target.name + ".old")
        target_key, victim_key = str(target.relative_to(base)), str(victim.relative_to(base))
        old_key, old_victim_key = str(old.relative_to(base)), str((old / "victim").relative_to(base))
        def replacement_predicate(_, value, kind=kind, ino=old_target[2], old_name=old.name):
            if value[0] != {"safe-dir": "dir", "link": "link", "file": "file"}[kind] or value[2] == ino or value[4] != os.geteuid(): return False
            if kind == "safe-dir": return value[3] == 0o700
            if kind == "link": return value[5] == old_name
            return value[3] == 0o600 and value[6] == hashlib.sha256(b"").hexdigest()

        schema_builder = lambda before: swap_delta(before, target_key, old_key, replacement_predicate)
        before, after, schema, actual_hooks = exercise(label, copy, root, plan, unsafe, hook, [f"MANAGED|{layer}|{target.name}|before_open|0|0"], base, schema_builder)
        replacement = signature(target)
        check(signature(old) == old_target and signature(old / "victim") == old_victim, f"{label}: victim")
        check(replacement[0] == {"safe-dir": "dir", "link": "link", "file": "file"}[kind], f"{label}: type")
        check(replacement[2] != old_target[2] and digest(copy) != provider_hash, f"{label}: identity/copy")
        if kind == "link": check(replacement[5] == target.name + ".old", f"{label}: readlink target")
        if layer == "root": oracle_probes[kind] = (before, after, schema, target_key, old_key, old_victim_key)
        if label == "swap-root-safe-dir": oracle_probe, swap_hook_probe = (before, after, schema), actual_hooks


def eexist(layer, kind):
    label = f"eexist-{layer}-{kind}"
    base, root, target, hook, copy, _, plan = setup(label, layer, False)
    plan[0], plan[3] = "eexist", kind
    expected = (0, f"{root}/project/session\n".encode(), b"") if kind == "safe" else unsafe if kind == "unsafe" else operation
    hooks = [f"MANAGED|{layer}|{target.name}|before_mkdir|0|0", f"MANAGED|{layer}|{target.name}|after_eexist|0|1"]
    target_key = str(target.relative_to(base))
    added = [target_key]
    if kind == "safe" and layer == "root": added += [f"{target_key}/project", f"{target_key}/project/session"]
    if kind == "safe" and layer == "project": added += [f"{target_key}/session"]
    if kind == "disappear": added = []
    predicate = safe_dir if kind == "safe" else lambda _, value: value[0] == "dir" and value[3] == 0o755
    schema_builder = lambda before: delta_schema(before, added, predicates={} if kind == "disappear" else {path: predicate for path in added})
    _, _, _, actual_hooks = exercise(label, copy, root, plan, expected, hook, hooks, base, schema_builder)
    if kind == "unsafe": check(signature(target)[3] == 0o755, f"{label}: unsafe winner")
    if kind == "disappear": check(not target.exists(), f"{label}: disappeared winner")
    return actual_hooks, hooks


eexist_hook_probe = eexist("root", "safe")
eexist("project", "unsafe")
eexist("session", "disappear")


def managed_case(kind, layer, include_target, expected, expected_hooks):
    label = f"{kind}-{layer}"
    base, root, target, hook, copy, _, plan = setup(label, layer, include_target)
    plan[0] = kind
    target_key, old_key = str(target.relative_to(base)), str(target.with_name(target.name + ".old").relative_to(base))
    if kind == "mkdir-replace":
        predicates = {target_key: lambda _, value: value[0] == "dir" and value[3] == 0o755, old_key: safe_dir}
        schema_builder = lambda before: delta_schema(before, (target_key, old_key), predicates=predicates)
    elif kind in ("open-disappear", "final-stat-disappear"):
        schema_builder = lambda before: delta_schema(before, removed=(target_key,))
    else:
        schema_builder = lambda before: delta_schema(before)
    hooks = expected_hooks(target.name)
    if kind == "mkdir-replace":
        hooks = lambda after: [f"MANAGED|{layer}|{target.name}|before_open|1|0|original={','.join(map(str, after[old_key][:5]))}"]
    _, _, _, actual_hooks = exercise(label, copy, root, plan, expected, hook, hooks, base, schema_builder)
    return base, target, actual_hooks


base, target, mkdir_hook_probe = managed_case("mkdir-replace", "root", False, unsafe, lambda name: [])
check(signature(target.with_name("state.old"))[3] == 0o700 and signature(target)[3] == 0o755, "mkdir replacement")

label = "wrong-euid-project"
base, root, target, hook, copy, _, plan = setup(label, "project", True, "EXPECTED_EUID")
plan[0] = "wrong-euid"
exercise(label, copy, root, plan, unsafe, hook, ["EXPECTED_EUID|project|project|N/A|0|0"], base, delta_schema)
check(not (target / "session").exists(), "wrong EUID traversal")

managed_case("mkdir-failure", "project", False, operation, lambda name: [f"MANAGED|project|{name}|before_mkdir|0|0"])
managed_case("post-mkdir-disappear", "session", False, operation, lambda name: [f"MANAGED|session|{name}|before_open|1|0"])
managed_case("open-disappear", "root", True, operation, lambda name: [f"MANAGED|root|{name}|before_open|0|0"])
managed_case("final-stat-disappear", "session", True, operation, lambda name: [f"MANAGED|session|{name}|before_open|0|0"])

label = "real-eio"
base = workspace / label; base.mkdir(); hook = workspace / f"{label}.hook"
copy, _ = injected_copy(base, "OS_ERROR")
plan = [label, "N/A", "N/A", "N/A", str(hook)]
exercise(label, copy, base / "state", plan, operation, hook, ["OS_ERROR|N/A|N/A|N/A|N/A|N/A"], base, delta_schema)
check(not (base / "state").exists(), "EIO created root")

probe_before, probe_after, probe_schema = oracle_probe
protected_path = next(iter(probe_schema["protected"]))
bad_signature = dict(probe_after); bad_signature[protected_path] = ("broken",) + bad_signature[protected_path][1:]
must_reject(lambda: assert_delta(probe_before, bad_signature, probe_schema, "signature-disproof"), "protected signature")
bad_inventory = dict(probe_after); bad_inventory["unexpected"] = next(iter(probe_after.values()))
must_reject(lambda: assert_delta(probe_before, bad_inventory, probe_schema, "inventory-disproof"), "inventory")
bad_allowed = dict(probe_schema); bad_allowed["allowed_changed_paths"] = set()
must_reject(lambda: assert_delta(probe_before, probe_after, bad_allowed, "allowed-delta-disproof"), "allowed delta")


def reject_field(kind, key_index, field_index, value, label):
    before, after, schema, *keys = oracle_probes[kind]
    broken = dict(after); item = list(broken[keys[key_index]]); item[field_index] = value; broken[keys[key_index]] = tuple(item)
    must_reject(lambda: assert_delta(before, broken, schema, f"{label}-disproof"), label)


reject_field("link", 0, 5, "wrong-target", "readlink target")
reject_field("file", 2, 6, "0" * 64, "file hash")
reject_field("safe-dir", 1, 3, 0o755, "mode")
reject_field("safe-dir", 1, 2, oracle_probes["safe-dir"][1][oracle_probes["safe-dir"][4]][2] + 1, "inode")
actual_hooks, expected_hooks = eexist_hook_probe
must_reject(lambda: assert_hooks(actual_hooks[:1], expected_hooks, "eexist-hook-disproof"), "EEXIST second hook")
must_reject(lambda: assert_marker_counts(source + markers["MANAGED"]), "marker count")
must_reject(lambda: assert_hooks([], swap_hook_probe, "sentinel-disproof"), "sentinel")
phase_parts = swap_hook_probe[0].split("|"); phase_parts[3] = "after_eexist"
must_reject(lambda: assert_hooks(["|".join(phase_parts)], swap_hook_probe, "phase-disproof"), "phase")
made_parts = mkdir_hook_probe[0].split("|"); made_parts[4] = "0"
must_reject(lambda: assert_hooks(["|".join(made_parts)], mkdir_hook_probe, "made-disproof"), "made")
catch_parts = actual_hooks[1].split("|"); catch_parts[5] = "0"
must_reject(lambda: assert_hooks([actual_hooks[0], "|".join(catch_parts)], expected_hooks, "catch-disproof"), "catch")
case_ids = case_log.read_text().splitlines()
expected_ids = [f"swap-{layer}-{kind}" for layer in ("root", "project", "session") for kind in ("safe-dir", "link", "file")] + [
    "eexist-root-safe", "eexist-project-unsafe", "eexist-session-disappear", "mkdir-replace-root", "wrong-euid-project",
    "mkdir-failure-project", "post-mkdir-disappear-session", "open-disappear-root", "final-stat-disappear-session", "real-eio"]
check(case_ids == expected_ids and len(set(case_ids)) == 19, "exact ordered unique case IDs")
must_reject(lambda: check(case_ids[:-1] == expected_ids, "case invocation disproof"), "case invocation")
check(self_disproofs == ["protected signature", "inventory", "allowed delta", "readlink target", "file hash", "mode", "inode", "EEXIST second hook", "marker count", "sentinel", "phase", "made", "catch", "case invocation"], "self-disproof execution")
check(provider.read_bytes() == source_bytes, "production provider changed")
PY
[[ $? == 0 ]] || fail 'race driver'
printf '%s\n' "$SUMMARY"
