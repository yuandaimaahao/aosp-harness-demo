"""Mutation oracle for the complete supersession-validator/v1 contract."""
from __future__ import annotations
import copy, json, os, pathlib, shutil, subprocess, sys, tempfile

from supersession_lib import ContractError
from modes import accept

DROP = object()
PASS = "RESULT PASS environment-seed-preflight-supersession-pre-commit\n"


def _change(source, path, value=DROP):
    result = copy.deepcopy(source); target = result
    for key in path[:-1]: target = target[key]
    key = path[-1]
    if value is DROP: target.pop(key)
    else: target[key] = value(target[key]) if callable(value) else value
    return result


def _public(command, code=None):
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                            env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"), check=False)
    expected = (0, PASS, "") if code is None else (1, "", f"RESULT FAIL supersession {code}\n")
    if (result.returncode, result.stdout, result.stderr) != expected:
        raise ContractError("INTERNAL_ERROR")


def _write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value if isinstance(value, str) else json.dumps(value) + "\n", encoding="utf-8")


def _pre_command(source, root, base, manifest):
    return [sys.executable, str(source / accept.PREFIX / "work/verify-supersession.py"),
            "pre-commit", "--project-root", str(root), "--base-commit", base,
            "--manifest", str(manifest)]


def _manifest_and_documents(source):
    with tempfile.TemporaryDirectory(prefix="supersession-schema-") as directory:
        root = pathlib.Path(directory)
        _, base, _, _, _ = accept._fixture(root)
        manifest_path = root / accept.PREFIX / "supersession.json"
        canonical = json.loads(manifest_path.read_text(encoding="utf-8"))
        command = _pre_command(source, root, base, manifest_path)
        duplicate = json.dumps(canonical).replace('"schema_version": 1',
                                                   '"schema_version": 1, "schema_version": 1', 1)
        cases = (
            ("duplicate", duplicate, "DUPLICATE_JSON_KEY"),
            ("missing", _change(canonical, ("kind",)), "MANIFEST_SCHEMA_INVALID"),
            ("unknown", _change(canonical, ("unknown",), 1), "MANIFEST_SCHEMA_INVALID"),
            ("type", _change(canonical, ("plan_version",), True), "MANIFEST_SCHEMA_INVALID"),
            ("order", _change(canonical, ("commit_paths",), lambda x: list(reversed(x))), "COMMIT_SCOPE_MISMATCH"),
            ("missing replacement", _change(canonical, ("replacements",), lambda x: x[:-1]), "MISSING_REPLACEMENT"),
            ("DAG", _change(canonical, ("replacements", 1, "depends_on"), []), "REPLACEMENT_DAG_INVALID"),
            ("missing owner", _change(canonical, ("requirement_owners",), lambda x: x[:-1]), "REQUIREMENT_OWNER_MISSING"),
            ("owner", _change(canonical, ("requirement_owners", 0, "owners"), ["current"]), "REQUIREMENT_OWNER_INVALID"),
            ("budget limit", _change(canonical, ("line_budgets", "successors", 0, "non_generated_max"), 801), "BUDGET_LIMIT_EXCEEDED"),
            ("budget relation", _change(canonical, ("line_budgets", "combined_original", "non_generated_min"), 1400), "BUDGET_INVALID"),
            ("path", _change(canonical, ("commit_paths", 0), "common/evil"), "COMMIT_SCOPE_MISMATCH"),
        )
        for _, mutation, code in cases:
            _write(manifest_path, mutation); _public(command, code)
        _write(manifest_path, canonical)
        project = root / ".spec/2026-09-01-aosp-feature-minimal-checkout"
        documents = ((project / "PLAN.md", "拆分计划 v6", "PLAN_INVALID"),
                     (project / "DECISIONS.md", "PLAN v6 owner/rollback", "DECISIONS_INVALID"),
                     (root / accept.PREFIX / "sizing-prototype.md",
                      "预计产生 890–1310 行非生成 diff", "SIZING_INVALID"))
        for path, needle, code in documents:
            original = path.read_text(encoding="utf-8")
            _write(path, original.replace(needle, "mutation", 1)); _public(command, code); _write(path, original)


def _pre_fixture(source, root, merge=False):
    accept._g(root, "init"); accept._g(root, "config", "user.email", "self@test")
    accept._g(root, "config", "user.name", "Self Test")
    project = root / ".spec/2026-09-01-aosp-feature-minimal-checkout"
    for name in ("PLAN.md", "DECISIONS.md"):
        target = project / name; target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / project.relative_to(root) / name, target)
    sizing = root / accept.PREFIX / "sizing-prototype.md"; sizing.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source / accept.PREFIX / "sizing-prototype.md", sizing)
    accept._g(root, "add", "."); accept._g(root, "commit", "-m", "base"); base = accept._g(root, "rev-parse", "HEAD")
    if merge:
        branch = accept._g(root, "branch", "--show-current"); accept._g(root, "checkout", "-b", "side")
        accept._g(root, "commit", "--allow-empty", "-m", "side"); accept._g(root, "checkout", branch)
        accept._g(root, "commit", "--allow-empty", "-m", "main"); accept._g(root, "merge", "--no-ff", "side", "-m", "merge")
    manifest = json.loads((source / accept.PREFIX / "supersession.json").read_text(encoding="utf-8"))
    manifest["base_commit"] = base; path = root / accept.PREFIX / "supersession.json"; _write(path, manifest)
    accept._g(root, "add", str(path.relative_to(root)))
    return _pre_command(source, root, base, path), base


def _git_and_accept(source):
    with tempfile.TemporaryDirectory(prefix="supersession-pre-") as directory:
        root = pathlib.Path(directory); command, _ = _pre_fixture(source, root)
        _public(command); wrong = list(command); wrong[wrong.index("--base-commit") + 1] = "0" * 40
        _public(wrong, "BASE_HEAD_MISMATCH")
        _write(root / "common/evil", "x\n"); _public(command, "COMMON_SCOPE_VIOLATION")
    with tempfile.TemporaryDirectory(prefix="supersession-merge-") as directory:
        command, _ = _pre_fixture(source, pathlib.Path(directory), True)
        _public(command, "COMMIT_SCOPE_MISMATCH")
    accept._self_test()
    for kind, code in (("fake-ledger", "LEDGER_SHA_MISMATCH"), ("task-owned-path", "COMMIT_SCOPE_MISMATCH")):
        with tempfile.TemporaryDirectory(prefix="supersession-accept-public-") as directory:
            root = pathlib.Path(directory); command, _, merge, _, ledger = accept._fixture(root, extra=kind == "task-owned-path")
            if kind == "fake-ledger":
                _write(ledger, ledger.read_text(encoding="utf-8").replace(f"commits=[{merge}]", f"commits=[{'0' * 40}]", 1))
            accept._expect(command, code)


def run(args, context):
    source = pathlib.Path(__file__).resolve().parents[6]
    _manifest_and_documents(source); _git_and_accept(source)
    return context["pass_line"]
