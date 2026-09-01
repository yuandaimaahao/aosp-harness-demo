#!/usr/bin/env python3
# THROWAWAY ROUND7 PROTOTYPE: private race-oracle driver.
import hashlib
import os
import pathlib
import stat
import subprocess
import sys
import tempfile

PROTOCOL = "session-path-race-driver-v1"
layers = ("root", "project", "session")


def default_rows():
    rows = [(f"swap-{layer}-{kind}", "swap", layer, kind) for layer in layers for kind in ("safe-dir", "link", "file")]
    rows += [(f"wrong-euid-{layer}", "wrong-euid", layer, "N/A") for layer in layers]
    rows += [(f"eexist-{layer}-{kind}", "eexist", layer, kind) for layer in layers for kind in ("safe", "unsafe", "disappear")]
    rows += [(f"{kind}-{layer}", kind, layer, "N/A") for kind in ("mkdir-replace", "mkdir-failure", "post-mkdir-disappear", "open-disappear", "final-stat-disappear") for layer in layers]
    return rows + [("real-eio", "real-eio", "N/A", "N/A")]

if sys.argv[1:] == ["protocol"]:
    print(PROTOCOL); raise SystemExit
if len(sys.argv) == 4 and sys.argv[1] == "self-test":
    mode = "self-test"
    foundation, provider = map(pathlib.Path, sys.argv[2:]); owner = tempfile.TemporaryDirectory(prefix="session-race-driver.")
    workspace, rows = pathlib.Path(owner.name) / "workspace", default_rows()
    case_log = workspace / "cases.log"
elif len(sys.argv) == 7 and sys.argv[1] == "run-matrix":
    mode = "run-matrix"
    foundation, provider, workspace, case_tsv, case_log = map(pathlib.Path, sys.argv[2:])
    rows = [tuple(line.split("\t")) for line in case_tsv.read_text().splitlines()]
else:
    print("usage: session-path-race-driver.py protocol|self-test FOUNDATION PROVIDER|run-matrix FOUNDATION PROVIDER WORKSPACE CASE_TSV CASE_LOG", file=sys.stderr)
    raise SystemExit(2)
allowed = {"swap": (layers, ("safe-dir", "link", "file")), "eexist": (layers, ("safe", "unsafe", "disappear"))}
for family in ("mkdir-replace", "mkdir-failure", "post-mkdir-disappear", "open-disappear", "final-stat-disappear", "wrong-euid"):
    allowed[family] = (layers, ("N/A",))
allowed["real-eio"] = (("N/A",), ("N/A",))
if not rows or len({row[0] for row in rows}) != len(rows):
    raise AssertionError("case TSV must contain unique rows")
for case_id, family, layer, variant in rows:
    expected_id = "real-eio" if family == "real-eio" else f"{family}-{layer}" if variant == "N/A" else f"{family}-{layer}-{variant}"
    if family not in allowed or layer not in allowed[family][0] or variant not in allowed[family][1] or case_id != expected_id:
        raise AssertionError("invalid case TSV row")
parent = workspace.parent
parent_info = parent.lstat()
if not workspace.is_absolute() or parent.resolve(strict=True) != parent or not stat.S_ISDIR(parent_info.st_mode):
    raise AssertionError("workspace parent must be a physical directory")
if os.path.lexists(workspace) or case_log.parent != workspace or os.path.lexists(case_log):
    raise AssertionError("workspace/log capability must be fresh and direct")
workspace.mkdir(mode=0o700, parents=False, exist_ok=False)
workspace_fd = os.open(workspace, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
os.fchmod(workspace_fd, 0o700)
workspace_info = os.fstat(workspace_fd)
if stat.S_IMODE(workspace_info.st_mode) != 0o700 or workspace_info.st_uid != os.geteuid():
    raise AssertionError("workspace identity")
log_fd = os.open(case_log.name, os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600, dir_fd=workspace_fd)
log_info = os.fstat(log_fd)
os.close(workspace_fd)
if stat.S_IMODE(log_info.st_mode) != 0o600 or log_info.st_uid != os.geteuid() or log_info.st_nlink != 1:
    raise AssertionError("case log identity")
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
executed = []
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
    paths = []
    for current, directories, files in os.walk(root, followlinks=False):
        current_path = pathlib.Path(current)
        for name in directories + files:
            paths.append(current_path / name)
    paths.sort(key=lambda path: os.fsencode(path.relative_to(root)))
    return {str(path.relative_to(root)): signature(path) for path in paths}

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
    executed.append(label)
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
if mode == "self-test":
    order_probe = workspace / "inventory-order"; order_probe.mkdir()
    for name in ("z-last", "a-first"): (order_probe / name).mkdir()
    check(list(inventory(order_probe)) == ["a-first", "z-last"], "C-locale filesystem-byte inventory order")
for _, family, layer, kind in rows:
    if family == "swap":
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


def wrong_euid(layer):
    label = f"wrong-euid-{layer}"
    base, root, target, hook, copy, _, plan = setup(label, layer, True, "EXPECTED_EUID")
    plan[0] = "wrong-euid"
    exercise(label, copy, root, plan, unsafe, hook, [f"EXPECTED_EUID|{layer}|{target.name}|N/A|0|0"], base, delta_schema)
    check(not (target / "session").exists(), "wrong EUID traversal")


for _, family, layer, _ in rows:
    if family == "wrong-euid": wrong_euid(layer)


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


for _, family, layer, kind in rows:
    if family == "eexist":
        hooks = eexist(layer, kind)
        if layer == "root" and kind == "safe": eexist_hook_probe = hooks


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


managed_specs = {
    "mkdir-replace": (False, unsafe, "before_open", 1), "mkdir-failure": (False, operation, "before_mkdir", 0),
    "post-mkdir-disappear": (False, operation, "before_open", 1), "open-disappear": (True, operation, "before_open", 0),
    "final-stat-disappear": (True, operation, "before_open", 0),
}
for _, kind, layer, _ in rows:
    if kind in managed_specs:
        include, expected, phase, made = managed_specs[kind]
        base, target, actual = managed_case(kind, layer, include, expected, lambda name: [f"MANAGED|{layer}|{name}|{phase}|{made}|0"])
        if kind == "mkdir-replace": check(signature(target.with_name(target.name + ".old"))[3] == 0o700 and signature(target)[3] == 0o755, "mkdir replacement")
        if kind == "mkdir-replace" and layer == "root": mkdir_hook_probe = actual

for label, family, _, _ in rows:
    if family == "real-eio":
        base = workspace / label; base.mkdir(); hook = workspace / f"{label}.hook"
        copy, _ = injected_copy(base, "OS_ERROR")
        plan = [label, "N/A", "N/A", "N/A", str(hook)]
        exercise(label, copy, base / "state", plan, operation, hook, ["OS_ERROR|N/A|N/A|N/A|N/A|N/A"], base, delta_schema)
        check(not (base / "state").exists(), "EIO created root")

if mode == "self-test":
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
expected_ids = [row[0] for row in rows]
check(len(executed) == len(rows) and set(executed) == set(expected_ids), "exact executed case set")
case_bytes = "".join(case_id + "\n" for case_id in expected_ids).encode()
check(provider.read_bytes() == source_bytes, "production provider changed")
check(os.write(log_fd, case_bytes) == len(case_bytes), "complete case log write")
os.lseek(log_fd, 0, os.SEEK_SET)
case_ids = os.read(log_fd, 1 << 20).decode().splitlines()
check(case_ids == expected_ids, "exact ordered unique case IDs")
if mode == "self-test":
    check(hashlib.sha256(case_bytes).hexdigest() == "721b3687bda848db7b6481c527f491e6733cf376dbade3dd37b319fce8029bc8", "ordered 37 case ID hash")
    must_reject(lambda: check(case_ids[:-1] == expected_ids, "case invocation disproof"), "case invocation")
    check(self_disproofs == ["protected signature", "inventory", "allowed delta", "readlink target", "file hash", "mode", "inode", "EEXIST second hook", "marker count", "sentinel", "phase", "made", "catch", "case invocation"], "self-disproof execution")
os.close(log_fd)
print("RESULT PASS  session path race driver")
