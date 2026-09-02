# review 包 c959efaf..b7ed7abb

## commit 列表

```
b7ed7ab fix(harness): validate canonical runtime arguments
214add6 fix(harness): restrict canonical JSON inputs
67db369 feat(harness): add canonical seed contract core
```

## diff --stat

```
 .../closure/v1/lib/seed_contract_runtime.py        | 36 ++++++++++++++++++++++
 common/tests/test_seed_contract_runtime.py         | 34 ++++++++++++++++++++
 2 files changed, 70 insertions(+)
```

## diff

```diff
diff --git a/common/.harness/closure/v1/lib/seed_contract_runtime.py b/common/.harness/closure/v1/lib/seed_contract_runtime.py
new file mode 100644
index 0000000..f8987ec
--- /dev/null
+++ b/common/.harness/closure/v1/lib/seed_contract_runtime.py
@@ -0,0 +1,36 @@
+import hashlib, json; RUNTIME_ABI, _SAFE = "seed-contract-runtime/v1", 2**53-1
+class ContractError(Exception):
+    def __init__(self, code): self._code = code if isinstance(code, str) else "ARGUMENT_ERROR"; super().__init__(self._code)
+    code = property(lambda self: self._code)
+def _pairs(pairs):
+    if len(result := dict(pairs)) != len(pairs): raise ContractError("DUPLICATE_JSON_KEY")
+    return result
+def _guard(value):
+    if value is None or isinstance(value, bool): return
+    if isinstance(value, int) and -_SAFE <= value <= _SAFE: return
+    if isinstance(value, str) and not any(0xd800 <= ord(c) <= 0xdfff for c in value): return
+    if isinstance(value, list):
+        for item in value: _guard(item)
+        return
+    if isinstance(value, dict):
+        for key, item in value.items():
+            if not isinstance(key, str) or not key.isascii(): raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
+            _guard(item)
+        return
+    raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
+def canonical_bytes(*, value):
+    _guard(value); return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
+def domain_digest(*, domain_ascii, value):
+    try: prefix = domain_ascii.encode("ascii")
+    except (AttributeError, UnicodeEncodeError): raise ContractError("ARGUMENT_ERROR") from None
+    return hashlib.sha256(prefix + canonical_bytes(value=value)).hexdigest()
+def load_artifact(*, path, expected_kind):
+    if type(path) is not str or type(expected_kind) is not str or not path or not expected_kind: raise ContractError("ARGUMENT_ERROR")
+    try: raw = open(path, "rb").read()
+    except (OSError, TypeError): raise ContractError("DESCRIPTOR_NOT_FOUND") from None
+    try: value = json.loads(raw.decode(), object_pairs_hook=_pairs)
+    except UnicodeDecodeError: raise ContractError("DESCRIPTOR_INVALID_UTF8") from None
+    except json.JSONDecodeError: raise ContractError("DESCRIPTOR_SCHEMA_INVALID") from None
+    _guard(value)
+    if not isinstance(value, dict) or value.get("kind") != expected_kind: raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
+    return value
diff --git a/common/tests/test_seed_contract_runtime.py b/common/tests/test_seed_contract_runtime.py
new file mode 100644
index 0000000..f10a0de
--- /dev/null
+++ b/common/tests/test_seed_contract_runtime.py
@@ -0,0 +1,34 @@
+#!/usr/bin/env python3
+import hashlib, os, subprocess, sys, tempfile
+from concurrent.futures import ThreadPoolExecutor
+from pathlib import Path
+sys.path.insert(0, str(Path(__file__).parents[1] / ".harness/closure/v1/lib"))
+try: from seed_contract_runtime import ContractError, RUNTIME_ABI, canonical_bytes, domain_digest, load_artifact
+except ModuleNotFoundError: print("FAIL canonical-core runtime/API missing", file=sys.stderr); raise SystemExit(1)
+def bad(fn, code):
+    try: fn()
+    except ContractError as error: assert error.code == code
+    else: raise AssertionError(code)
+def core():
+    assert RUNTIME_ABI == "seed-contract-runtime/v1"
+    assert ContractError(7).code == "ARGUMENT_ERROR"
+    assert canonical_bytes(value={"b":"雪","a":1}) == b'{"a":1,"b":"\xe9\x9b\xaa"}'
+    assert canonical_bytes(value={"a":1,"b":"雪"}) == canonical_bytes(value={"b":"雪","a":1})
+    for n in (-(2**53-1), 2**53-1): canonical_bytes(value=n)
+    for n in (-2**53, 2**53): bad(lambda n=n: canonical_bytes(value=n), "DESCRIPTOR_SCHEMA_INVALID")
+    for s in ("\ud800", "\udc00"): bad(lambda s=s: canonical_bytes(value=s), "DESCRIPTOR_SCHEMA_INVALID")
+    for value in ((1,2), {1:"v"}, {1:"a","1":"b"}): bad(lambda value=value: canonical_bytes(value=value), "DESCRIPTOR_SCHEMA_INVALID")
+    for fn in (canonical_bytes, lambda **kw: domain_digest(domain_ascii="test/v1\0", **kw)): bad(lambda fn=fn: fn(value={"\ue000":1,"\U00010000":2}), "DESCRIPTOR_SCHEMA_INVALID")
+    with tempfile.TemporaryDirectory() as directory:
+        p = Path(directory) / "seed.json"
+        for raw, code in ((b'{"kind":"seed","kind":"seed"}', "DUPLICATE_JSON_KEY"), (b'{"kind":"seed","x":"\\ud800"}', "DESCRIPTOR_SCHEMA_INVALID")):
+            p.write_bytes(raw); bad(lambda: load_artifact(path=str(p), expected_kind="seed"), code)
+    for kwargs in ({"path":None,"expected_kind":"seed"}, {"path":"missing","expected_kind":1}): bad(lambda kwargs=kwargs: load_artifact(**kwargs), "ARGUMENT_ERROR")
+    assert domain_digest(domain_ascii="test/v1\0", value={"a":1}) == hashlib.sha256(b'test/v1\0{"a":1}').hexdigest()
+def concurrent():
+    with ThreadPoolExecutor(max_workers=8) as pool: outcomes = list(pool.map(lambda _: subprocess.run([sys.executable, __file__, "canonical-core"], capture_output=True, text=True, env={**os.environ,"PYTHONDONTWRITEBYTECODE":"1"}), range(20)))
+    assert all((r.returncode, r.stdout, r.stderr) == (0, "PASS canonical-core\n", "") for r in outcomes)
+if __name__ == "__main__":
+    cases = {"canonical-core": core, "concurrent-core": concurrent}
+    try: cases[sys.argv[1]](); print("PASS " + sys.argv[1])
+    except (IndexError, KeyError): raise SystemExit("usage: canonical-core|concurrent-core") from None
```
