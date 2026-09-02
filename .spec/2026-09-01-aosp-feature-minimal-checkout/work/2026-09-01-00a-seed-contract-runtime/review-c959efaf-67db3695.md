# review 包 c959efaf..67db3695

## commit 列表

```
67db369 feat(harness): add canonical seed contract core
```

## diff --stat

```
 .../closure/v1/lib/seed_contract_runtime.py        | 41 ++++++++++++++++++++++
 common/tests/test_seed_contract_runtime.py         | 24 +++++++++++++
 2 files changed, 65 insertions(+)
```

## diff

```diff
diff --git a/common/.harness/closure/v1/lib/seed_contract_runtime.py b/common/.harness/closure/v1/lib/seed_contract_runtime.py
new file mode 100644
index 0000000..eb5841f
--- /dev/null
+++ b/common/.harness/closure/v1/lib/seed_contract_runtime.py
@@ -0,0 +1,41 @@
+"""Canonical JSON primitives for the seed-contract runtime."""
+import hashlib, json
+RUNTIME_ABI, _SAFE = "seed-contract-runtime/v1", 2**53-1
+class ContractError(Exception):
+    __slots__ = ("_code",)
+    def __init__(self, code): self._code = code; super().__init__(code)
+    @property
+    def code(self): return self._code
+def _pairs(pairs):
+    result = {}
+    for key, value in pairs:
+        if key in result: raise ContractError("DUPLICATE_JSON_KEY")
+        result[key] = value
+    return result
+def _guard(value):
+    if value is None or isinstance(value, bool): return
+    if isinstance(value, int) and -_SAFE <= value <= _SAFE: return
+    if isinstance(value, str) and not any(0xd800 <= ord(c) <= 0xdfff for c in value): return
+    if isinstance(value, (list, tuple)):
+        for item in value: _guard(item)
+        return
+    if isinstance(value, dict):
+        for key, item in value.items(): _guard(key); _guard(item)
+        return
+    raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
+def canonical_bytes(*, value):
+    _guard(value)
+    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
+def domain_digest(*, domain_ascii, value):
+    try: prefix = domain_ascii.encode("ascii")
+    except (AttributeError, UnicodeEncodeError): raise ContractError("ARGUMENT_ERROR") from None
+    return hashlib.sha256(prefix + canonical_bytes(value=value)).hexdigest()
+def load_artifact(*, path, expected_kind):
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
index 0000000..26dbfbe
--- /dev/null
+++ b/common/tests/test_seed_contract_runtime.py
@@ -0,0 +1,24 @@
+#!/usr/bin/env python3
+import hashlib, sys
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
+    assert canonical_bytes(value={"b":"雪","a":1}) == b'{"a":1,"b":"\xe9\x9b\xaa"}'
+    assert canonical_bytes(value={"a":1,"b":"雪"}) == canonical_bytes(value={"b":"雪","a":1})
+    for n in (-(2**53-1), 2**53-1): canonical_bytes(value=n)
+    for n in (-2**53, 2**53): bad(lambda n=n: canonical_bytes(value=n), "DESCRIPTOR_SCHEMA_INVALID")
+    for s in ("\ud800", "\udc00"): bad(lambda s=s: canonical_bytes(value=s), "DESCRIPTOR_SCHEMA_INVALID")
+    p = Path(__file__).with_suffix(".json")
+    for raw, code in ((b'{"kind":"seed","kind":"seed"}', "DUPLICATE_JSON_KEY"), (b'{"kind":"seed","x":"\\ud800"}', "DESCRIPTOR_SCHEMA_INVALID")):
+        p.write_bytes(raw); bad(lambda: load_artifact(path=str(p), expected_kind="seed"), code)
+    p.unlink(); assert domain_digest(domain_ascii="test/v1\0", value={"a":1}) == hashlib.sha256(b'test/v1\0{"a":1}').hexdigest()
+if __name__ == "__main__":
+    if sys.argv[1:] != ["canonical-core"]: raise SystemExit("usage: canonical-core")
+    core(); print("PASS canonical-core")
```
