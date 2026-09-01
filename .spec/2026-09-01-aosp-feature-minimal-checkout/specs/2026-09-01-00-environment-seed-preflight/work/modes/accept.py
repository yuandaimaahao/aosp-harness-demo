"""Exact merge acceptance and isolated rollback gate."""
from __future__ import annotations
import json, os, pathlib, re, shutil, subprocess, sys, tempfile
try:
    from supersession_lib import ContractError, load_and_validate_manifest, validate_plan
except ModuleNotFoundError:
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
    from supersession_lib import ContractError, load_and_validate_manifest, validate_plan

PREFIX = ".spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/"
ARTIFACT = ".spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/"
OWNED = [("supersession.json", "work/supersession_lib.py", "work/verify-supersession.py"),
         ("work/modes/pre_commit.py",), ("work/modes/accept.py",), ("work/modes/self_test.py",)]
TASK = re.compile(r"^- 任务 ([1-4]): 完成 commits=\[([0-9a-f]{40})\] report=" + ARTIFACT.replace(".", r"\.") +
                  r"task-\1-report\.md review=" + ARTIFACT.replace(".", r"\.") +
                  r"review-task-\1-([0-9a-f]{12})-([0-9a-f]{12})\.md$")
MERGE = re.compile(r"^- merge: 完成 commits=\[([0-9a-f]{40})\] parent1=\[([0-9a-f]{40})\] parent2=\[([0-9a-f]{40})\]$")
BYTECODE = re.compile(b"^" + re.escape(PREFIX.encode()) +
                      rb"work/(?:__pycache__/supersession_lib|modes/__pycache__/(?:accept|pre_commit|self_test))\.cpython-[0-9]+\.pyc$")
REGRESSIONS = (("./common/tests/test-harness.sh", "RESULT PASS  shared Harness regression suite"),
               ("./common/.harness/bin/check-parity.sh", "PARITY PASS  Claude/Codex 共享同一公共契约"),
               ("./common/.harness/features/dev-sidebar/verify-sidebar.sh --demo", "RESULT PASS"))

def _proc(argv, **kw):
    return subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, **kw)

def _git(root, *argv):
    result = _proc(["git", "-C", str(root), *argv], text=True)
    if result.returncode: raise ContractError("LEDGER_SHA_MISMATCH")
    return result.stdout.strip()

def _ledger(path):
    try: lines = path.read_text(encoding="utf-8").splitlines()
    except OSError: raise ContractError("LEDGER_INCOMPLETE") from None
    tasks, joined = {}, None
    for line in lines:
        task, merge = TASK.fullmatch(line), MERGE.fullmatch(line)
        if line.startswith("- 任务 "):
            if not task or int(task[1]) in tasks: raise ContractError("LEDGER_FORMAT_INVALID")
            number, sha, parent, tip = task.groups()
            if sha[:12] != tip or (number != "1" and parent == tip): raise ContractError("LEDGER_SHA_MISMATCH")
            tasks[int(number)] = sha, parent
        elif line.startswith("- merge:"):
            if not merge or joined: raise ContractError("LEDGER_FORMAT_INVALID")
            joined = merge.groups()
    if set(tasks) != {1, 2, 3, 4} or not joined: raise ContractError("LEDGER_INCOMPLETE")
    rows = [tasks[n] for n in range(1, 5)]
    return [x[0] for x in rows], [x[1] for x in rows], joined

def _artifacts(root, tasks, parents):
    for n, (sha, parent) in enumerate(zip(tasks, parents), 1):
        for name in (f"task-{n}-report.md", f"review-task-{n}-{parent[:12]}-{sha[:12]}.md"):
            path = root / ARTIFACT / name
            if not path.is_file() or path.is_symlink(): raise ContractError("LEDGER_INCOMPLETE")

def _clean(root, paths):
    for scope, code in ((["common"], "COMMON_SCOPE_VIOLATION"), (paths, "COMMIT_SCOPE_MISMATCH")):
        result = _proc(["git", "-C", str(root), "status", "--porcelain=v2", "-z", "--untracked-files=all", "--", *scope])
        if result.returncode or result.stdout: raise ContractError(code)
    parents = sorted({str(pathlib.PurePosixPath(p).parent) for p in paths})
    result = _proc(["git", "-C", str(root), "ls-files", "--others", "--exclude-standard", "-z", "--", *parents])
    if result.returncode or any(not BYTECODE.fullmatch(p) for p in result.stdout.split(b"\0") if p): raise ContractError("COMMIT_SCOPE_MISMATCH")

def _structure(root, base, merge, tasks, anchors, joined, paths):
    if not re.fullmatch(r"[0-9a-f]{40}", merge) or joined != (merge, base, tasks[-1]): raise ContractError("LEDGER_SHA_MISMATCH")
    if _git(root, "rev-parse", "--verify", f"{merge}^{{commit}}") != merge: raise ContractError("LEDGER_SHA_MISMATCH")
    if _git(root, "rev-parse", "HEAD") != merge: raise ContractError("BASE_HEAD_MISMATCH")
    if _git(root, "show", "-s", "--format=%P", merge).split() != [base, tasks[-1]]: raise ContractError("COMMIT_TYPE_INVALID")
    expected = [[PREFIX + p for p in group] for group in OWNED]
    if sorted(sum(expected, [])) != paths or sorted(_git(root, "diff", "--name-only", base, merge).splitlines()) != paths: raise ContractError("COMMIT_SCOPE_MISMATCH")
    parents = [base] + tasks[:-1]
    for sha, parent, owned in zip(tasks, parents, expected):
        if _git(root, "show", "-s", "--format=%P", sha).split() != [parent]: raise ContractError("COMMIT_TYPE_INVALID")
        if sorted(_git(root, "diff", "--name-only", parent, sha).splitlines()) != owned: raise ContractError("COMMIT_SCOPE_MISMATCH")
    if anchors != [p[:12] for p in parents]: raise ContractError("LEDGER_SHA_MISMATCH")

def _budget(root, base, merge):
    total = 0
    for row in _git(root, "diff", "--numstat", base, merge).splitlines():
        fields = row.split("\t", 2)
        if len(fields) != 3 or not fields[0].isdigit() or not fields[1].isdigit(): raise ContractError("COMMIT_SCOPE_MISMATCH")
        total += int(fields[0]) + int(fields[1])
    if total > 800: raise ContractError("BUDGET_LIMIT_EXCEEDED")

def _registered(root, worktree):
    result = _proc(["git", "-C", str(root), "worktree", "list", "--porcelain"], text=True)
    return bool(result.returncode), f"worktree {worktree}\n" in result.stdout + "\n"

def _rollback(root, merge, paths, base):
    worktree = pathlib.Path(tempfile.mkdtemp(prefix="supersession-revert-")); shutil.rmtree(worktree)
    failure = None
    try:
        if _proc(["git", "-C", str(root), "worktree", "add", "--detach", str(worktree), merge]).returncode: raise ContractError("ROLLBACK_MISMATCH")
        if _proc(["git", "-C", str(worktree), "revert", "-m", "1", "--no-edit", merge]).returncode: raise ContractError("ROLLBACK_MISMATCH")
        if any((worktree / p).exists() for p in paths) or _git(worktree, "diff", "--name-only", base, "HEAD"): raise ContractError("ROLLBACK_MISMATCH")
        for command, expected in REGRESSIONS:
            result = _proc(["bash", "-lc", command], cwd=worktree, text=True)
            if result.returncode or result.stderr or result.stdout.splitlines()[-1:] != [expected]: raise ContractError("REGRESSION_FAILED")
    except ContractError as error: failure = error
    finally:
        list_failed, registered = _registered(root, worktree); remove_failed = False
        if registered or worktree.exists(): remove_failed = bool(_proc(["git", "-C", str(root), "worktree", "remove", "--force", str(worktree)]).returncode)
        list_failed2, registered2 = _registered(root, worktree)
        if worktree.exists() and not registered2:
            try: shutil.rmtree(worktree)
            except OSError: pass
        cleanup_failed = any((list_failed, remove_failed, list_failed2, registered2, worktree.exists()))
    if failure: raise failure
    if cleanup_failed: raise ContractError("ROLLBACK_MISMATCH")

def run(args, context):
    root, manifest = pathlib.Path(args.project_root).resolve(), load_and_validate_manifest(pathlib.Path(args.manifest))
    if args.base_commit != manifest["base_commit"]: raise ContractError("BASE_HEAD_MISMATCH")
    validate_plan(root, manifest); tasks, anchors, joined = _ledger(pathlib.Path(args.ledger))
    _artifacts(root, tasks, anchors); _clean(root, manifest["commit_paths"])
    _structure(root, args.base_commit, args.merge_commit, tasks, anchors, joined, manifest["commit_paths"])
    _budget(root, args.base_commit, args.merge_commit); _rollback(root, args.merge_commit, manifest["commit_paths"], args.base_commit)
    return context["pass_line"]

def _write(path, text, mode=False):
    path.parent.mkdir(parents=True, exist_ok=True); path.write_text(text, encoding="utf-8")
    if mode: path.chmod(0o755)

def _g(root, *args):
    result = _proc(["git", "-C", str(root), *args], text=True)
    if result.returncode: raise RuntimeError(result.stderr)
    return result.stdout.strip()

def _fixture(root, large=False, bad_regression=False, extra=False):
    _g(root, "init"); _g(root, "config", "user.email", "self@test"); _g(root, "config", "user.name", "Self Test")
    source = pathlib.Path(__file__).resolve().parents[6]; project = root / ".spec/2026-09-01-aosp-feature-minimal-checkout"; (root / PREFIX).mkdir(parents=True)
    for name in ("PLAN.md", "DECISIONS.md"): shutil.copyfile(source / ".spec/2026-09-01-aosp-feature-minimal-checkout" / name, project / name)
    shutil.copyfile(source / PREFIX / "sizing-prototype.md", root / PREFIX / "sizing-prototype.md")
    for path, line in REGRESSIONS: _write(root / path.split()[0][2:], ("exit 1" if bad_regression and "test-harness" in path else f"echo '{line}'") + "\n", True)
    _write(root / PREFIX / "ledger.md", "base\n"); _write(root / PREFIX / "tasks.md", "base\n")
    _write(root / "baseline", "ok\n"); _g(root, "add", "."); _g(root, "commit", "-m", "base"); base = _g(root, "rev-parse", "HEAD")
    manifest = json.loads((source / PREFIX / "supersession.json").read_text()); manifest["base_commit"] = base
    initial = _g(root, "branch", "--show-current"); _g(root, "checkout", "-b", "tasks"); tasks = []
    for n, group in enumerate(OWNED, 1):
        for name in group: _write(root / (PREFIX + name), json.dumps(manifest) if name == "supersession.json" else (("x\n" * 801) if large and n == 4 else f"{n}\n"))
        if extra and n == 4: _write(root / "common/evil", "x\n")
        _g(root, "add", "."); _g(root, "commit", "-m", f"task {n}"); tasks.append(_g(root, "rev-parse", "HEAD"))
    _g(root, "checkout", initial); _g(root, "merge", "--no-ff", "tasks", "-m", "merge"); merge = _g(root, "rev-parse", "HEAD")
    manifest_path = root / PREFIX / "supersession.json"
    parents = [base] + tasks[:-1]; lines = [f"- 任务 {n}: 完成 commits=[{sha}] report={ARTIFACT}task-{n}-report.md review={ARTIFACT}review-task-{n}-{parent[:12]}-{sha[:12]}.md" for n, (sha, parent) in enumerate(zip(tasks, parents), 1)]
    ledger = root / "ledger.md"; _write(ledger, "\n".join(lines + [f"- merge: 完成 commits=[{merge}] parent1=[{base}] parent2=[{tasks[-1]}]"]) + "\n")
    for n, (sha, parent) in enumerate(zip(tasks, parents), 1):
        _write(root / ARTIFACT / f"task-{n}-report.md", "report\n"); _write(root / ARTIFACT / f"review-task-{n}-{parent[:12]}-{sha[:12]}.md", "review\n")
    command = [sys.executable, str(source / PREFIX / "work/verify-supersession.py"), "accept", "--project-root", str(root), "--base-commit", base, "--manifest", str(manifest_path), "--merge-commit", merge, "--ledger", str(ledger)]
    return command, base, merge, tasks, ledger

def _expect(command, code, env=None):
    result = _proc(command, text=True, env=env or dict(os.environ, PYTHONDONTWRITEBYTECODE="1"))
    if (result.returncode, result.stdout, result.stderr) != (1, "", f"RESULT FAIL supersession {code}\n"): raise ContractError("INTERNAL_ERROR")

def _self_test():
    with tempfile.TemporaryDirectory(prefix="supersession-accept-") as directory:
        root = pathlib.Path(directory); command, base, merge, tasks, ledger = _fixture(root)
        result = _proc(command, text=True, env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"))
        if (result.returncode, result.stdout, result.stderr) != (0, "RESULT PASS environment-seed-preflight-supersession-acceptance\n", ""): raise ContractError("INTERNAL_ERROR")
        _write(root / PREFIX / "ledger.md", "dirty\n"); _write(root / PREFIX / "tasks.md", "dirty\n")
        _write(root / PREFIX / "work/__pycache__/supersession_lib.cpython-312.pyc", "generated\n"); _write(root / PREFIX / "work/modes/__pycache__/accept.cpython-312.pyc", "generated\n")
        result = _proc(command, text=True, env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"))
        if (result.returncode, result.stdout, result.stderr) != (0, "RESULT PASS environment-seed-preflight-supersession-acceptance\n", ""): raise ContractError("INTERNAL_ERROR")
        original = ledger.read_text(); _write(ledger, original + original.splitlines()[0] + "\n"); _expect(command, "LEDGER_FORMAT_INVALID"); _write(ledger, original)
        report = root / ARTIFACT / "task-1-report.md"; report.unlink(); _expect(command, "LEDGER_INCOMPLETE"); _write(report, "report\n")
        _write(root / "advanced", "x\n"); _g(root, "add", "advanced"); _g(root, "commit", "-m", "advance"); _expect(command, "BASE_HEAD_MISMATCH"); _g(root, "reset", "--hard", merge)
        task_command = list(command); task_command[task_command.index("--merge-commit") + 1] = tasks[-1]
        _write(ledger, "\n".join(original.splitlines()[:-1] + [f"- merge: 完成 commits=[{tasks[-1]}] parent1=[{base}] parent2=[{tasks[-1]}]"]) + "\n"); _g(root, "checkout", "--detach", tasks[-1]); _expect(task_command, "COMMIT_TYPE_INVALID"); _g(root, "checkout", "--detach", merge); _write(ledger, original)
        tracked = (("common/tests/test-harness.sh", "COMMON_SCOPE_VIOLATION"), (PREFIX + "work/modes/accept.py", "COMMIT_SCOPE_MISMATCH"))
        for state, (path, code) in ((state, item) for state in ("worktree", "staged", "untracked") for item in tracked):
            target = root / (path if state != "untracked" else str(pathlib.PurePosixPath(path).parent / "stray")); _write(target, "dirty\n")
            if state == "staged": _g(root, "add", str(target.relative_to(root)))
            _expect(command, code); _g(root, "reset", "--hard", merge); _g(root, "clean", "-fd", "--", "common", PREFIX)
        fake = root / "bin/git"; real_git = shutil.which("git")
        _write(fake, f'''#!/bin/sh\nif [ "$3 $4" = "worktree add" ] && [ "$FAULT" = partial ]; then "{real_git}" "$@"; exit 1; fi\nif [ "$3 $4" = "worktree remove" ] && [ "$FAULT" = cleanup ]; then "{real_git}" "$@"; exit 1; fi\nif [ "$3" = revert ] && [ "$FAULT" = leftover ]; then exit 0; fi\nexec "{real_git}" "$@"\n''', True)
        for fault in ("partial", "cleanup", "leftover"):
            _expect(command, "ROLLBACK_MISMATCH", dict(os.environ, PATH=str(fake.parent) + os.pathsep + os.environ["PATH"], FAULT=fault, PYTHONDONTWRITEBYTECODE="1"))
            if "supersession-revert-" in _g(root, "worktree", "list", "--porcelain"): raise ContractError("INTERNAL_ERROR")
        _expect(command, "INTERNAL_ERROR", dict(os.environ, PATH="", PYTHONDONTWRITEBYTECODE="1"))
    for large, bad, extra, code in ((True, False, False, "BUDGET_LIMIT_EXCEEDED"), (False, True, False, "REGRESSION_FAILED"), (False, False, True, "COMMIT_SCOPE_MISMATCH")):
        with tempfile.TemporaryDirectory(prefix="supersession-negative-") as directory: _expect(_fixture(pathlib.Path(directory), large, bad, extra)[0], code)

def main(argv):
    try:
        if argv != ["self-test"]: raise ContractError("ARGUMENT_ERROR")
        _self_test()
    except ContractError as error: print(f"RESULT FAIL supersession {error.code}", file=sys.stderr); return 1
    except Exception: print("RESULT FAIL supersession INTERNAL_ERROR", file=sys.stderr); return 1
    print("RESULT PASS supersession-accept-mode-self-test"); return 0

if __name__ == "__main__": raise SystemExit(main(sys.argv[1:]))
