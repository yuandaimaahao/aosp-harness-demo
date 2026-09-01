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

operation = (1, b"", b"error: session state operation failed\n")
markers = {
    "MANAGED": "HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN",
    "EXPECTED_EUID": "HARNESS_TEST_MARKER_EXPECTED_EUID",
    "OS_ERROR": "HARNESS_TEST_MARKER_OS_ERROR",
}
source = provider.read_text()
source_bytes = provider.read_bytes()
executed = []
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


def injected_copy(base):
    marker = markers["OS_ERROR"]
    assert_marker_counts(source)
    lines = source.splitlines(keepends=True)
    indexes = [index for index, line in enumerate(lines) if marker in line]
    check(len(indexes) == 1, "anchor line OS_ERROR")
    original = lines[indexes[0]]
    lines[indexes[0]] = os_hook + "\n"
    expected = source.replace(original, os_hook + "\n", 1)
    copy = base / "provider.sh"
    copy.write_text("".join(lines))
    check(copy.read_text() == expected, "strict replacement OS_ERROR")
    check(all(copy.read_text().count(marker_text) == 1 for marker_text in markers.values()), "copy anchor counts")
    return copy


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


def exercise_eio(label):
    base = workspace / label
    base.mkdir()
    hook = workspace / f"{label}.hook"
    copy = injected_copy(base)
    before = inventory(base)
    result = invoke(copy, base / "state", [label, "N/A", "N/A", "N/A", str(hook)])
    after = inventory(base)
    check((result.returncode, result.stdout, result.stderr) == operation, f"{label}: protocol")
    check(hook.read_text().splitlines() == ["OS_ERROR|N/A|N/A|N/A|N/A|N/A"], f"{label}: ordered hooks")
    assert_delta(before, after, delta_schema(before), label)
    check(not (base / "state").exists(), "EIO created root")
    executed.append(label)


for row_case_id, row_family, _, _ in rows:
    if row_family != "real-eio":
        raise AssertionError("matrix executor incomplete")
    exercise_eio(row_case_id)

expected_ids = [row[0] for row in rows]
check(len(executed) == len(rows) and set(executed) == set(expected_ids), "exact executed case set")
case_bytes = "".join(case_id + "\n" for case_id in expected_ids).encode()
check(provider.read_bytes() == source_bytes, "production provider changed")
check(os.write(log_fd, case_bytes) == len(case_bytes), "complete case log write")
os.lseek(log_fd, 0, os.SEEK_SET)
check(os.read(log_fd, 1 << 20).decode().splitlines() == expected_ids, "exact ordered unique case IDs")
os.close(log_fd)
print("RESULT PASS  session path race driver")
