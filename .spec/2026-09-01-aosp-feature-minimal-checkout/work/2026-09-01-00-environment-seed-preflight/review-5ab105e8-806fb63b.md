# review 包 5ab105e8..806fb63b

## commit 列表

```
806fb63 feat(spec): add supersession pre-commit mode
```

## diff --stat

```
 .../work/modes/pre_commit.py                       | 77 ++++++++++++++++++++++
 1 file changed, 77 insertions(+)
```

## diff

```diff
diff --git a/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/modes/pre_commit.py b/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/modes/pre_commit.py
new file mode 100644
index 0000000..af8ae8f
--- /dev/null
+++ b/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/modes/pre_commit.py
@@ -0,0 +1,77 @@
+"""Base-relative prospective-tree gate for supersession-validator/v1."""
+
+from __future__ import annotations
+
+import pathlib
+import subprocess
+
+from supersession_lib import ContractError, load_and_validate_manifest, validate_plan
+
+
+def _git(root: pathlib.Path, *argv: str) -> str:
+    result = subprocess.run(
+        ["git", "-C", str(root), *argv],
+        stdout=subprocess.PIPE,
+        stderr=subprocess.PIPE,
+        text=True,
+        check=False,
+    )
+    if result.returncode:
+        raise ContractError("BASE_HEAD_MISMATCH")
+    return result.stdout
+
+
+def _prospective_paths(root: pathlib.Path, base: str) -> list[str]:
+    return sorted(filter(None, _git(root, "diff", "--cached", "--name-only", base).splitlines()))
+
+
+def _common_changed(root: pathlib.Path, base: str) -> bool:
+    if _git(root, "diff", "--cached", "--name-only", base, "--", "common").strip():
+        return True
+    return bool(_git(root, "status", "--porcelain", "--untracked-files=all", "--", "common").strip())
+
+
+def _linear_descendant(root: pathlib.Path, base: str) -> None:
+    result = subprocess.run(
+        ["git", "-C", str(root), "merge-base", "--is-ancestor", base, "HEAD"],
+        stdout=subprocess.PIPE,
+        stderr=subprocess.PIPE,
+        text=True,
+        check=False,
+    )
+    if result.returncode:
+        raise ContractError("BASE_HEAD_MISMATCH")
+    if _git(root, "rev-list", "--merges", f"{base}..HEAD").strip():
+        raise ContractError("COMMIT_SCOPE_MISMATCH")
+
+
+def _check_budget(root: pathlib.Path, base: str) -> None:
+    total = 0
+    for row in _git(root, "diff", "--cached", "--numstat", base).splitlines():
+        fields = row.split("\t", 2)
+        if len(fields) != 3 or not fields[0].isdigit() or not fields[1].isdigit():
+            raise ContractError("COMMIT_SCOPE_MISMATCH")
+        total += int(fields[0]) + int(fields[1])
+    if total > 800:
+        raise ContractError("BUDGET_LIMIT_EXCEEDED")
+
+
+def run(args, context):
+    root = pathlib.Path(args.project_root).resolve()
+    manifest = load_and_validate_manifest(pathlib.Path(args.manifest))
+    if args.base_commit != manifest["base_commit"]:
+        raise ContractError("BASE_HEAD_MISMATCH")
+    validate_plan(root, manifest)
+    _linear_descendant(root, args.base_commit)
+
+    paths = _prospective_paths(root, args.base_commit)
+    allowed = manifest["commit_paths"]
+    if _common_changed(root, args.base_commit):
+        raise ContractError("COMMON_SCOPE_VIOLATION")
+    if not set(paths) <= set(allowed):
+        raise ContractError("COMMIT_SCOPE_MISMATCH")
+    if args.require_complete:
+        if paths != allowed:
+            raise ContractError("COMMIT_SCOPE_MISMATCH")
+        _check_budget(root, args.base_commit)
+    return context["pass_line"]
```
