# review 包 7b46dfba..f81b2d8d

## commit 列表

```
f81b2d8 docs(spec): add supersession manifest core
```

## diff --stat

```
 .../supersession.json                              |  55 +++++
 .../work/supersession_lib.py                       | 230 +++++++++++++++++++++
 .../work/verify-supersession.py                    |  73 +++++++
 3 files changed, 358 insertions(+)
```

## diff

```diff
diff --git a/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/supersession.json b/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/supersession.json
new file mode 100644
index 0000000..e046e09
--- /dev/null
+++ b/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/supersession.json
@@ -0,0 +1,55 @@
+{
+  "schema_version": 1,
+  "kind": "spec_supersession",
+  "base_commit": "7b46dfba287f2e3e3fb9ca00c3186b69c4720dc7",
+  "plan_version": 6,
+  "superseded_spec": "2026-09-01-00-environment-seed-preflight",
+  "replacements": [
+    {"id": "2026-09-01-00a-seed-contract-runtime", "depends_on": []},
+    {"id": "2026-09-01-00b-environment-seed-probe", "depends_on": ["2026-09-01-00a-seed-contract-runtime"]}
+  ],
+  "requirement_owners": [
+    {"requirement": "R1", "owners": ["00b"]},
+    {"requirement": "R2", "owners": ["00b"]},
+    {"requirement": "R3", "owners": ["00b"]},
+    {"requirement": "R4", "owners": ["00b"]},
+    {"requirement": "R5", "owners": ["00a"]},
+    {"requirement": "R6", "owners": ["00b"]},
+    {"requirement": "R7", "owners": ["00b"]},
+    {"requirement": "R8", "owners": ["00a"]},
+    {"requirement": "R9", "owners": ["00b"]},
+    {"requirement": "R10", "owners": ["00b"]},
+    {"requirement": "R11", "owners": ["00b"]},
+    {"requirement": "R12", "owners": ["00b"]},
+    {"requirement": "R13", "owners": ["00b"]},
+    {"requirement": "R14", "owners": ["00b"]},
+    {"requirement": "R15", "owners": ["00b"]},
+    {"requirement": "R16", "owners": ["00b"]},
+    {"requirement": "R17", "owners": ["00b"]},
+    {"requirement": "R18", "owners": ["00b"]},
+    {"requirement": "R19", "owners": ["00b"]},
+    {"requirement": "R20", "owners": ["00b"]},
+    {"requirement": "R21", "owners": ["00a", "00b"]},
+    {"requirement": "R22", "owners": ["00a"]},
+    {"requirement": "R23", "owners": ["00a", "00b"]},
+    {"requirement": "R24", "owners": ["current"]},
+    {"requirement": "R25", "owners": ["00a", "00b"]},
+    {"requirement": "R26", "owners": ["00b"]},
+    {"requirement": "R27", "owners": ["00a", "00b"]}
+  ],
+  "line_budgets": {
+    "combined_original": {"non_generated_min": 890, "non_generated_max": 1310},
+    "successors": [
+      {"id": "2026-09-01-00a-seed-contract-runtime", "non_generated_min": 610, "non_generated_max": 730, "review_summary_max": 140},
+      {"id": "2026-09-01-00b-environment-seed-probe", "non_generated_min": 470, "non_generated_max": 630, "review_summary_max": 160}
+    ]
+  },
+  "commit_paths": [
+    ".spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/supersession.json",
+    ".spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/modes/accept.py",
+    ".spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/modes/pre_commit.py",
+    ".spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/modes/self_test.py",
+    ".spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/supersession_lib.py",
+    ".spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/verify-supersession.py"
+  ]
+}
diff --git a/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/supersession_lib.py b/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/supersession_lib.py
new file mode 100644
index 0000000..8fc37f4
--- /dev/null
+++ b/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/supersession_lib.py
@@ -0,0 +1,230 @@
+"""Closed supersession/v1 manifest and project-plan validation."""
+
+from __future__ import annotations
+
+import json
+import pathlib
+import re
+import subprocess
+from typing import Any, Iterable
+
+
+class ContractError(Exception):
+    def __init__(self, code: str):
+        super().__init__(code)
+        self.code = code
+
+
+REPLACEMENTS = [
+    {"id": "2026-09-01-00a-seed-contract-runtime", "depends_on": []},
+    {"id": "2026-09-01-00b-environment-seed-probe", "depends_on": ["2026-09-01-00a-seed-contract-runtime"]},
+]
+OWNERS = {f"R{number}": ["00b"] for number in range(1, 28)}
+OWNERS.update({
+    "R5": ["00a"], "R8": ["00a"], "R21": ["00a", "00b"],
+    "R22": ["00a"], "R23": ["00a", "00b"], "R24": ["current"],
+    "R25": ["00a", "00b"], "R27": ["00a", "00b"],
+})
+PREFIX = (".spec/2026-09-01-aosp-feature-minimal-checkout/specs/"
+          "2026-09-01-00-environment-seed-preflight/")
+COMMIT_PATHS = [PREFIX + suffix for suffix in (
+    "supersession.json", "work/modes/accept.py", "work/modes/pre_commit.py",
+    "work/modes/self_test.py", "work/supersession_lib.py", "work/verify-supersession.py",
+)]
+EXPECTED_BUDGETS = {
+    "combined_original": {"non_generated_min": 890, "non_generated_max": 1310},
+    "successors": [
+        {"id": REPLACEMENTS[0]["id"], "non_generated_min": 610,
+         "non_generated_max": 730, "review_summary_max": 140},
+        {"id": REPLACEMENTS[1]["id"], "non_generated_min": 470,
+         "non_generated_max": 630, "review_summary_max": 160},
+    ],
+}
+
+
+def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
+    result: dict[str, Any] = {}
+    for key, value in pairs:
+        if key in result:
+            raise ContractError("DUPLICATE_JSON_KEY")
+        result[key] = value
+    return result
+
+
+def _closed(value: Any, keys: Iterable[str]) -> dict[str, Any]:
+    if not isinstance(value, dict) or set(value) != set(keys):
+        raise ContractError("MANIFEST_SCHEMA_INVALID")
+    return value
+
+
+def _uint(value: Any) -> int:
+    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
+        raise ContractError("MANIFEST_SCHEMA_INVALID")
+    return value
+
+
+def _strings(value: Any) -> list[str]:
+    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
+        raise ContractError("MANIFEST_SCHEMA_INVALID")
+    return value
+
+
+def _validate_replacements(value: Any) -> None:
+    if not isinstance(value, list):
+        raise ContractError("MANIFEST_SCHEMA_INVALID")
+    parsed = []
+    for item in value:
+        item = _closed(item, ("id", "depends_on"))
+        if not isinstance(item["id"], str):
+            raise ContractError("MANIFEST_SCHEMA_INVALID")
+        parsed.append({"id": item["id"], "depends_on": _strings(item["depends_on"])})
+    actual_ids = [item["id"] for item in parsed]
+    if any(item["id"] not in actual_ids for item in REPLACEMENTS):
+        raise ContractError("MISSING_REPLACEMENT")
+    if len(actual_ids) != len(set(actual_ids)) or parsed != REPLACEMENTS:
+        raise ContractError("REPLACEMENT_DAG_INVALID")
+
+
+def _validate_owners(value: Any) -> None:
+    if not isinstance(value, list):
+        raise ContractError("MANIFEST_SCHEMA_INVALID")
+    parsed: dict[str, list[str]] = {}
+    order = []
+    for item in value:
+        item = _closed(item, ("requirement", "owners"))
+        requirement, owners = item["requirement"], _strings(item["owners"])
+        if not isinstance(requirement, str):
+            raise ContractError("MANIFEST_SCHEMA_INVALID")
+        if requirement in parsed or not owners or owners != sorted(set(owners)):
+            raise ContractError("REQUIREMENT_OWNER_INVALID")
+        if not set(owners) <= {"current", "00a", "00b"} or ("current" in owners and requirement != "R24"):
+            raise ContractError("REQUIREMENT_OWNER_INVALID")
+        parsed[requirement], order = owners, order + [requirement]
+    if any(requirement not in parsed for requirement in OWNERS):
+        raise ContractError("REQUIREMENT_OWNER_MISSING")
+    if order != list(OWNERS) or parsed != OWNERS:
+        raise ContractError("REQUIREMENT_OWNER_INVALID")
+
+
+def _validate_budgets(value: Any) -> None:
+    value = _closed(value, ("combined_original", "successors"))
+    combined = _closed(value["combined_original"], ("non_generated_min", "non_generated_max"))
+    if _uint(combined["non_generated_min"]) > _uint(combined["non_generated_max"]):
+        raise ContractError("BUDGET_INVALID")
+    if not isinstance(value["successors"], list):
+        raise ContractError("MANIFEST_SCHEMA_INVALID")
+    for item in value["successors"]:
+        item = _closed(item, ("id", "non_generated_min", "non_generated_max", "review_summary_max"))
+        if not isinstance(item["id"], str):
+            raise ContractError("MANIFEST_SCHEMA_INVALID")
+        minimum, maximum = _uint(item["non_generated_min"]), _uint(item["non_generated_max"])
+        if maximum > 800 or _uint(item["review_summary_max"]) > 160:
+            raise ContractError("BUDGET_LIMIT_EXCEEDED")
+        if minimum > maximum:
+            raise ContractError("BUDGET_INVALID")
+    if value != EXPECTED_BUDGETS:
+        raise ContractError("BUDGET_INVALID")
+
+
+def _validate_paths(value: Any) -> None:
+    paths = _strings(value)
+    for path in paths:
+        parts = path.split("/")
+        invalid = (not path or path.startswith("/") or any(part in {"", ".", ".."} for part in parts)
+                   or re.search(r"[*?\[\]{}]", path) or "…" in path
+                   or pathlib.PurePosixPath(path).as_posix() != path or path.startswith("common/"))
+        if invalid:
+            raise ContractError("COMMIT_SCOPE_MISMATCH")
+    if paths != sorted(set(paths)) or paths != COMMIT_PATHS:
+        raise ContractError("COMMIT_SCOPE_MISMATCH")
+
+
+def load_and_validate_manifest(path: pathlib.Path) -> dict[str, Any]:
+    try:
+        manifest = json.loads(path.read_bytes().decode("utf-8"), object_pairs_hook=_pairs)
+    except ContractError:
+        raise
+    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
+        raise ContractError("MANIFEST_SCHEMA_INVALID") from None
+    manifest = _closed(manifest, (
+        "schema_version", "kind", "base_commit", "plan_version", "superseded_spec",
+        "replacements", "requirement_owners", "line_budgets", "commit_paths",
+    ))
+    if (manifest["schema_version"] != 1 or isinstance(manifest["schema_version"], bool)
+            or manifest["kind"] != "spec_supersession" or manifest["plan_version"] != 6
+            or manifest["superseded_spec"] != "2026-09-01-00-environment-seed-preflight"):
+        raise ContractError("MANIFEST_SCHEMA_INVALID")
+    if not isinstance(manifest["base_commit"], str) or not re.fullmatch(r"[0-9a-f]{40}", manifest["base_commit"]):
+        raise ContractError("BASE_HEAD_MISMATCH")
+    _validate_replacements(manifest["replacements"])
+    _validate_owners(manifest["requirement_owners"])
+    _validate_budgets(manifest["line_budgets"])
+    _validate_paths(manifest["commit_paths"])
+    return manifest
+
+
+def _read(path: pathlib.Path, code: str) -> str:
+    try:
+        return path.read_text(encoding="utf-8")
+    except (OSError, UnicodeError):
+        raise ContractError(code) from None
+
+
+def _plan_rows(text: str) -> list[list[str]]:
+    section = re.search(r"(?ms)^## spec 列表\s*$\n(.*?)(?=^## )", text)
+    if not section:
+        raise ContractError("PLAN_INVALID")
+    rows = []
+    for line in section.group(1).splitlines():
+        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
+        if line.startswith("|") and len(cells) == 5 and cells[0] != "id" and re.search(r"[A-Za-z0-9]", cells[0]):
+            rows.append(cells)
+    return rows
+
+
+def _require(text: str, fragments: Iterable[str], code: str) -> None:
+    if any(fragment not in text for fragment in fragments):
+        raise ContractError(code)
+
+
+def validate_plan(project_root: pathlib.Path, manifest: dict[str, Any]) -> None:
+    project = project_root.resolve() / ".spec/2026-09-01-aosp-feature-minimal-checkout"
+    plan_path, decisions_path = project / "PLAN.md", project / "DECISIONS.md"
+    sizing_path = project / "specs/2026-09-01-00-environment-seed-preflight/sizing-prototype.md"
+    plan = _read(plan_path, "PLAN_INVALID")
+    if plan.splitlines()[:1] != ["# 2026-09-01-aosp-feature-minimal-checkout 拆分计划 v6"]:
+        raise ContractError("PLAN_INVALID")
+    rows = _plan_rows(plan)
+    ids, expected = [row[0] for row in rows], [row["id"] for row in manifest["replacements"]]
+    if any(item not in ids for item in expected):
+        raise ContractError("MISSING_REPLACEMENT")
+    if ids[:2] != expected or manifest["superseded_spec"] in ids:
+        raise ContractError("PLAN_INVALID")
+    if rows[0][2] != "—" or "≤730 行" not in rows[0][3] or rows[1][2] != expected[0] or "≤630 行" not in rows[1][3]:
+        raise ContractError("PLAN_INVALID")
+    _require(plan, (
+        "门③ sizing 估算 890–1310 行非生成 diff", "拆后高位分别 730/630 行",
+        "`verify-seed --ref ... --require-public-real` 退 0，control plane 才记录 `GATE CONTINUE_PUBLIC`",
+        "parent1=base、parent2=task tip的two-parent merge验收",
+    ), "PLAN_INVALID")
+    _require(_read(decisions_path, "DECISIONS_INVALID"), (
+        "PLAN v6 owner/rollback", "原 00 因 890–1310 行估算超 800 拆为 00a/00b",
+        "00a/00b diff 高位分别 730/630 行", "原 00 supersession merge（替代 single-parent 例外）",
+        "parent1=frozen process base、parent2=task tip的two-parent merge交付",
+        "`git revert -m 1 --no-edit MERGE_SHA`",
+    ), "DECISIONS_INVALID")
+    _require(_read(sizing_path, "SIZING_INVALID"), (
+        "预计产生 890–1310 行非生成 diff", "| 原 00 总量 | — | — | 890–1310 |",
+        "`610–730 + 620–820 - 240–340`", "合计 610–730，review summary 100–140 行",
+        "区间合计 470–630，review summary 120–160 行", "00a 高位 730、00b 高位 630",
+    ), "SIZING_INVALID")
+    checkers = [pathlib.Path.home() / suffix for suffix in (
+        ".agents/skills/spec/scripts/check-plan.py", ".codex/skills/spec/scripts/check-plan.py",
+    )]
+    checker = next((path for path in checkers if path.is_file()), None)
+    if checker is None:
+        raise ContractError("PLAN_INVALID")
+    result = subprocess.run(["python3", str(checker), str(plan_path)], stdout=subprocess.PIPE,
+                            stderr=subprocess.PIPE, text=True, check=False)
+    if result.returncode:
+        raise ContractError("PLAN_INVALID")
diff --git a/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/verify-supersession.py b/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/verify-supersession.py
new file mode 100644
index 0000000..5d5eb7a
--- /dev/null
+++ b/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/verify-supersession.py
@@ -0,0 +1,73 @@
+#!/usr/bin/env python3
+"""Fail-closed dispatcher for supersession-validator/v1."""
+
+import argparse
+import importlib.util
+import pathlib
+import sys
+
+from supersession_lib import ContractError
+
+
+PASS_LINES = {
+    "self-test": "RESULT PASS environment-seed-preflight-supersession-self-test",
+    "pre-commit": "RESULT PASS environment-seed-preflight-supersession-pre-commit",
+    "accept": "RESULT PASS environment-seed-preflight-supersession-acceptance",
+}
+
+
+class ClosedParser(argparse.ArgumentParser):
+    def error(self, message):
+        raise ContractError("ARGUMENT_ERROR")
+
+
+def _parse(argv):
+    parser = ClosedParser(add_help=False)
+    commands = parser.add_subparsers(dest="mode", required=True)
+    commands.add_parser("self-test", add_help=False)
+    pre_commit = commands.add_parser("pre-commit", add_help=False)
+    accept = commands.add_parser("accept", add_help=False)
+    for target in (pre_commit, accept):
+        target.add_argument("--project-root", required=True)
+        target.add_argument("--base-commit", required=True)
+        target.add_argument("--manifest", required=True)
+    pre_commit.add_argument("--require-complete", action="store_true")
+    accept.add_argument("--merge-commit", required=True)
+    accept.add_argument("--ledger", required=True)
+    return parser.parse_args(argv)
+
+
+def _load(path, mode):
+    module_path = path / "modes" / f"{mode.replace('-', '_')}.py"
+    if not module_path.is_file():
+        raise ContractError("CAPABILITY_UNAVAILABLE")
+    spec = importlib.util.spec_from_file_location(f"supersession_mode_{mode}", module_path)
+    if spec is None or spec.loader is None:
+        raise ContractError("CAPABILITY_UNAVAILABLE")
+    module = importlib.util.module_from_spec(spec)
+    spec.loader.exec_module(module)
+    if not callable(getattr(module, "run", None)):
+        raise ContractError("CAPABILITY_UNAVAILABLE")
+    return module
+
+
+def main(argv):
+    try:
+        args = _parse(argv)
+        dispatcher = pathlib.Path(__file__).resolve()
+        expected = PASS_LINES[args.mode]
+        context = {"dispatcher_path": dispatcher, "work_dir": dispatcher.parent, "pass_line": expected}
+        if _load(dispatcher.parent, args.mode).run(args, context) != expected:
+            raise ContractError("INTERNAL_ERROR")
+    except ContractError as exc:
+        print(f"RESULT FAIL supersession {exc.code}", file=sys.stderr)
+        return 1
+    except Exception:
+        print("RESULT FAIL supersession INTERNAL_ERROR", file=sys.stderr)
+        return 1
+    print(expected)
+    return 0
+
+
+if __name__ == "__main__":
+    raise SystemExit(main(sys.argv[1:]))
```
