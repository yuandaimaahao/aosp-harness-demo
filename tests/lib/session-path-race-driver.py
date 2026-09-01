#!/usr/bin/env python3
import hashlib
import os
import pathlib
import stat
import subprocess
import sys

PROTOCOL = "session-path-race-driver-v1"
LAYERS = ("root", "project", "session")

if sys.argv[1:] == ["protocol"]:
    print(PROTOCOL)
    raise SystemExit
if len(sys.argv) == 4 and sys.argv[1] == "self-test":
    raise AssertionError("matrix executor incomplete")
elif len(sys.argv) == 7 and sys.argv[1] == "run-matrix":
    foundation, provider, workspace, case_tsv, case_log = map(pathlib.Path, sys.argv[2:])
else:
    raise SystemExit(2)

case_text = case_tsv.read_text()
if "\0" in case_text:
    raise AssertionError("case TSV contains NUL")
rows = [tuple(line.split("\t")) for line in case_text.splitlines()]
if not rows or any(len(row) != 4 or any(not field for field in row) for row in rows):
    raise AssertionError("case TSV must contain exact nonempty columns")
if len({row[0] for row in rows}) != len(rows):
    raise AssertionError("case TSV must contain unique IDs")

allowed = {"swap": (LAYERS, ("safe-dir", "link", "file")), "eexist": (LAYERS, ("safe", "unsafe", "disappear"))}
for family_name in ("mkdir-replace", "mkdir-failure", "post-mkdir-disappear", "open-disappear", "final-stat-disappear", "wrong-euid"):
    allowed[family_name] = (LAYERS, ("N/A",))
allowed["real-eio"] = (("N/A",), ("N/A",))
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
executed = []
managed_hook = r'''    _kind, _layer, _expected_name, _detail, _hook = os.environ["HARNESS_RACE_PLAN"].split("|", 4)
    _match = ((_kind == "swap" and phase == "before_open" and not made)
              or (_kind == "eexist" and phase in ("before_mkdir", "after_eexist")))
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
        paths.extend(current_path / name for name in directories + files)
    paths.sort(key=lambda path: os.fsencode(path.relative_to(root)))
    return {str(path.relative_to(root)): signature(path) for path in paths}


def delta_schema(before, added=(), removed=(), changed=(), predicates=None):
    removed, changed = set(removed), set(changed)
    return {
        "paths_added": set(added),
        "paths_removed": removed,
        "protected": {path: value for path, value in before.items() if path not in removed | changed},
        "allowed_changed_paths": changed,
        "predicates": predicates or {},
    }


def assert_delta(before, after, schema, label):
    before_paths, after_paths = set(before), set(after)
    check(after_paths - before_paths == schema["paths_added"], f"{label}: paths added")
    check(before_paths - after_paths == schema["paths_removed"], f"{label}: paths removed")
    check(all(after.get(path) == value for path, value in schema["protected"].items()), f"{label}: protected signatures")
    changed = {path for path in before_paths & after_paths if before[path] != after[path]}
    check(changed == schema["allowed_changed_paths"], f"{label}: changed paths")
    check(all(path in after and predicate(before.get(path), after[path]) for path, predicate in schema["predicates"].items()), f"{label}: predicates")


def assert_marker_counts(text):
    check(all(text.count(marker) == 1 for marker in markers.values()), "source anchor counts")


def assert_hooks(actual, expected, label):
    check(actual == expected, f"{label}: ordered hooks {actual!r}")


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
    check(all(copy.read_text().count(marker_text) == 1 for marker_text in markers.values()), "copy anchor counts")
    return copy, hashlib.sha256(source.encode()).hexdigest()


def make_parents(base, layer, include_target=True):
    root, target = base / "state", base / "state"
    if layer != "root":
        root.mkdir(mode=0o700)
        target = root / "project"
    if layer == "session":
        target.mkdir(mode=0o700)
        target = target / "session"
    if include_target:
        target.mkdir(mode=0o700)
    return root, target


def invoke(copy, root, plan):
    environment = os.environ.copy()
    environment.pop("XDG_RUNTIME_DIR", None)
    environment.pop("TMPDIR", None)
    environment["HARNESS_STATE_ROOT"] = str(root)
    environment["HARNESS_RACE_PLAN"] = "|".join(plan)
    return subprocess.run(
        ["bash", "-c", 'source "$1"; source "$2"; _harness_session_path_core "$3" "$4"', "_", str(foundation), str(copy), "project", "session"],
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def exercise(label, copy, root, plan, expected, hook, hook_lines, base, schema_builder):
    before = inventory(base)
    result = invoke(copy, root, plan)
    after = inventory(base)
    check((result.returncode, result.stdout, result.stderr) == expected, f"{label}: protocol")
    assert_hooks(hook.read_text().splitlines(), hook_lines, label)
    assert_delta(before, after, schema_builder(before), label)
    executed.append(label)


def setup(label, layer, include_target=True, anchor="MANAGED"):
    base = workspace / label
    base.mkdir()
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


def swap(layer, kind):
    label = f"swap-{layer}-{kind}"
    base, root, target, hook, copy, provider_hash, plan = setup(label, layer)
    plan[0], plan[3] = "swap", kind
    victim = target / "victim"
    victim.write_text("sentinel")
    old_target, old_victim = signature(target), signature(victim)
    old = target.with_name(target.name + ".old")
    target_key, old_key = str(target.relative_to(base)), str(old.relative_to(base))

    def replacement_predicate(_, value):
        if value[0] != {"safe-dir": "dir", "link": "link", "file": "file"}[kind] or value[2] == old_target[2] or value[4] != os.geteuid():
            return False
        if kind == "safe-dir":
            return value[3] == 0o700
        if kind == "link":
            return value[5] == old.name
        return value[3] == 0o600 and value[6] == hashlib.sha256(b"").hexdigest()

    exercise(label, copy, root, plan, unsafe, hook, [f"MANAGED|{layer}|{target.name}|before_open|0|0"], base,
             lambda before: swap_delta(before, target_key, old_key, replacement_predicate))
    check(signature(old) == old_target and signature(old / "victim") == old_victim, f"{label}: victim subtree")
    replacement = signature(target)
    check(replacement[2] != old_target[2] and digest(copy) != provider_hash, f"{label}: identity/copy")


def wrong_euid(layer):
    label = f"wrong-euid-{layer}"
    base, root, target, hook, copy, _, plan = setup(label, layer, anchor="EXPECTED_EUID")
    plan[0] = "wrong-euid"
    exercise(label, copy, root, plan, unsafe, hook, [f"EXPECTED_EUID|{layer}|{target.name}|N/A|0|0"], base, delta_schema)
    check(not (target / "session").exists(), f"{label}: no later layer")


def eexist(layer, kind):
    label = f"eexist-{layer}-{kind}"
    base, root, target, hook, copy, _, plan = setup(label, layer, False)
    plan[0], plan[3] = "eexist", kind
    expected = (0, f"{root}/project/session\n".encode(), b"") if kind == "safe" else unsafe if kind == "unsafe" else operation
    hooks = [f"MANAGED|{layer}|{target.name}|before_mkdir|0|0", f"MANAGED|{layer}|{target.name}|after_eexist|0|1"]
    target_key = str(target.relative_to(base))
    added = [target_key]
    if kind == "safe" and layer == "root":
        added += [f"{target_key}/project", f"{target_key}/project/session"]
    if kind == "safe" and layer == "project":
        added += [f"{target_key}/session"]
    if kind == "disappear":
        added = []
    predicate = safe_dir if kind == "safe" else lambda _, value: value[0] == "dir" and value[3] == 0o755
    exercise(label, copy, root, plan, expected, hook, hooks, base,
             lambda before: delta_schema(before, added, predicates={} if kind == "disappear" else {path: predicate for path in added}))
    if kind == "unsafe":
        check(signature(target)[3] == 0o755, f"{label}: unsafe winner")
    if kind == "disappear":
        check(not target.exists(), f"{label}: disappeared winner")


def exercise_eio(label):
    base = workspace / label
    base.mkdir()
    hook = workspace / f"{label}.hook"
    copy, _ = injected_copy(base, "OS_ERROR")
    exercise(label, copy, base / "state", [label, "N/A", "N/A", "N/A", str(hook)], operation, hook,
             ["OS_ERROR|N/A|N/A|N/A|N/A|N/A"], base, delta_schema)
    check(not (base / "state").exists(), "EIO created root")


for row_case_id, row_family, row_layer, row_variant in rows:
    if row_family == "swap":
        swap(row_layer, row_variant)
    elif row_family == "wrong-euid":
        wrong_euid(row_layer)
    elif row_family == "eexist":
        eexist(row_layer, row_variant)
    elif row_family == "real-eio":
        exercise_eio(row_case_id)
    else:
        raise AssertionError("matrix executor incomplete")

expected_ids = [row[0] for row in rows]
check(executed == expected_ids, "exact ordered executed case set")
case_bytes = "".join(case_id + "\n" for case_id in expected_ids).encode()
check(provider.read_bytes() == source_bytes, "production provider changed")
check(os.write(log_fd, case_bytes) == len(case_bytes), "complete case log write")
os.lseek(log_fd, 0, os.SEEK_SET)
check(os.read(log_fd, 1 << 20).decode().splitlines() == expected_ids, "exact ordered unique case IDs")
os.close(log_fd)
print("RESULT PASS  session path race driver")
