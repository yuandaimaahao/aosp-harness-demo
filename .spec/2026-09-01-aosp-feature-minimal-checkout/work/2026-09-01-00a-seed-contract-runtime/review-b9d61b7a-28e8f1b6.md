# review 包 b9d61b7a..28e8f1b6

## commit 列表

```
28e8f1b fix(harness): enforce evidence loader priority
5337b6d fix(harness): tighten evidence validation
67cc360 feat(harness): validate evidence schemas
```

## diff --stat

```
 .../closure/v1/lib/seed_contract_runtime.py        | 55 +++++++++++++++++++++-
 common/tests/test_seed_contract_runtime.py         | 25 ++++++++--
 2 files changed, 75 insertions(+), 5 deletions(-)
```

## diff

```diff
diff --git a/common/.harness/closure/v1/lib/seed_contract_runtime.py b/common/.harness/closure/v1/lib/seed_contract_runtime.py
index cc4b1a2..caa8d2d 100644
--- a/common/.harness/closure/v1/lib/seed_contract_runtime.py
+++ b/common/.harness/closure/v1/lib/seed_contract_runtime.py
@@ -1,11 +1,11 @@
-import hashlib, json; RUNTIME_ABI, _SAFE = "seed-contract-runtime/v1", 2**53-1
+import base64, hashlib, json, os; RUNTIME_ABI, _SAFE = "seed-contract-runtime/v1", 2**53-1
 class ContractError(Exception):
     def __init__(self, code: str) -> None: self._code = code if isinstance(code, str) else "ARGUMENT_ERROR"; super().__init__(self._code)
     code = property(lambda self: self._code)
 def _pairs(pairs):
     if len(result := dict(pairs)) != len(pairs): raise ContractError("DUPLICATE_JSON_KEY")
     return result
 def _guard(value):
     if value is None or isinstance(value, bool): return
     if isinstance(value, int) and -_SAFE <= value <= _SAFE: return
     if isinstance(value, str) and not any(0xd800 <= ord(c) <= 0xdfff for c in value): return
@@ -16,20 +16,71 @@ def _guard(value):
         for key, item in value.items():
             if not isinstance(key, str) or not key.isascii(): raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
             _guard(item)
         return
     raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
 def canonical_bytes(*, value: object) -> bytes:
     _guard(value); return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
 def domain_digest(*, domain_ascii: str, value: object) -> str:
     if type(domain_ascii) is not str or not domain_ascii.isascii(): raise ContractError("ARGUMENT_ERROR")
     return hashlib.sha256(domain_ascii.encode() + canonical_bytes(value=value)).hexdigest()
+_DOMAINS={"seed_request":"aosp-harness/seed-request/v1\0","project_source_state":"aosp-harness/project-source-state/v1\0","source_state":"aosp-harness/source-state/v1\0","trace":"aosp-harness/trace/v1\0","command_journal":"aosp-harness/command-journal/v1\0"}
+def _bad(): raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
+def _exact(v, keys): _bad() if type(v) is not dict or set(v) != set(keys) else None
+def _u(v): _bad() if type(v) is not int or not 0 <= v <= _SAFE else None
+def _i(v): _bad() if type(v) is not int or not -_SAFE <= v <= _SAFE else None
+def _text(v, ascii=False): _bad() if type(v) is not str or not v or ascii and not v.isascii() else None
+def _hex(v, lengths=(64,)): _bad() if type(v) is not str or len(v) not in lengths or any(c not in "0123456789abcdef" for c in v) else None
+def _b64(v):
+    try:
+        if type(v) is not str or base64.b64encode(base64.b64decode(v, validate=True)).decode() != v: _bad()
+    except (ValueError,base64.binascii.Error): _bad()
+    return base64.b64decode(v)
+def _rel(v): _text(v); _bad() if v.startswith("/") or any(x in ("", ".", "..") for x in v.split("/")) else None
+def _scope(v): _exact(v,("role","public_aosp_baseline","vendor_context","platform_family")); type(v["public_aosp_baseline"]) is type(v["vendor_context"]) is bool or _bad(); _bad() if v not in ({"role":"public_aosp17_cuttlefish","public_aosp_baseline":True,"vendor_context":False,"platform_family":"aosp-17"},{"role":"local_lk7k_product","public_aosp_baseline":False,"vendor_context":True,"platform_family":"aosp-17"}) else None
+def _entry(v):
+    _exact(v,("path_b64","status_record_b64","entry_kind","mode","content_sha256","symlink_target_sha256")); _b64(v["path_b64"]); _b64(v["status_record_b64"]); _u(v["mode"])
+    {"regular":lambda:(_hex(v["content_sha256"]),v["symlink_target_sha256"] is None or _bad()),"symlink":lambda:(_hex(v["symlink_target_sha256"]),v["content_sha256"] is None or _bad()),"missing":lambda:v["mode"] == 0 and v["content_sha256"] is None and v["symlink_target_sha256"] is None or _bad()}.get(v["entry_kind"],_bad)()
+def _project(v):
+    _exact(v,("path","head","status_sha256","entries")); _rel(v["path"]); _hex(v["head"],(40,64)); _hex(v["status_sha256"])
+    type(v["entries"]) is list or _bad(); [_entry(x) for x in v["entries"]]
+    if [_b64(x["path_b64"]) for x in v["entries"]] != sorted({_b64(x["path_b64"]) for x in v["entries"]}): _bad()
+    return _DOMAINS["project_source_state"]
+def _request(v):
+    _exact(v,("schema_version","kind","source_root","envsetup_relpath","lunch","source_scope","resource_minimums","estimated_disk_upper_bound_bytes")); _text(v["source_root"]); _rel(v["envsetup_relpath"]); _scope(v["source_scope"]); _u(v["estimated_disk_upper_bound_bytes"])
+    "\0" not in v["source_root"] and v["source_root"].startswith("/") and v["source_root"] == os.path.realpath(v["source_root"]) and v["envsetup_relpath"] == "build/envsetup.sh" or _bad(); _exact(v["lunch"],("target","product","release","variant")); [_text(x) for x in v["lunch"].values()]; _exact(v["resource_minimums"],("available_bytes","available_inodes","effective_memory_bytes","effective_cpus")); [_u(x) for x in v["resource_minimums"].values()]
+def _state(v):
+    _exact(v,("schema_version","kind","manifest_sha256","projects")); _hex(v["manifest_sha256"])
+    type(v["projects"]) is list or _bad(); [_project(x) for x in v["projects"]]
+    if [x["path"].encode() for x in v["projects"]] != sorted({x["path"].encode() for x in v["projects"]}): _bad()
+def _trace(v):
+    kinds=("other","external_network","source_mutation","sync_download","config_query","module_build","package"); _exact(v,("schema_version","kind","records","counts")); _exact(v["counts"],kinds)
+    if type(v["records"]) is not list: _bad()
+    for r in v["records"]:
+        _exact(r,("sequence","process_ordinal","syscall","result","errno","exec_argv_b64","paths","address_family","classification")); _u(r["sequence"]); _u(r["process_ordinal"]); _text(r["syscall"],True); _i(r["result"])
+        if (r["result"] >= 0) != (r["errno"] is None): _bad()
+        if r["errno"] is not None: _text(r["errno"],True)
+        {"execve":lambda:type(r["exec_argv_b64"]) is list or _bad(),"execveat":lambda:type(r["exec_argv_b64"]) is list or _bad()}.get(r["syscall"],lambda:r["exec_argv_b64"] is None or _bad())(); r["syscall"] not in ("execve","execveat") or [_b64(x) for x in r["exec_argv_b64"]]
+        if type(r["paths"]) is not list or r["address_family"] not in (None,"AF_INET","AF_INET6","AF_UNIX","AF_OTHER") or r["classification"] not in kinds: _bad()
+        for p in r["paths"]: _exact(p,("role","dirfd","raw_b64","resolved_b64")); _b64(p["raw_b64"]); _b64(p["resolved_b64"]); p["dirfd"] is None or _i(p["dirfd"]); p["role"] in ("path","oldpath","newpath","target","linkpath","source_fd","destination_fd") or _bad()
+    if [r["sequence"] for r in v["records"]] != sorted({r["sequence"] for r in v["records"]}): _bad()
+    for k in kinds: _u(v["counts"][k]); v["counts"][k] == sum(r["classification"] == k and r["result"] >= 0 for r in v["records"]) or _bad()
+def _journal(v):
+    stages=("manifest_before","source_state_before","namespace_probe","envsetup_lunch","manifest_after","source_state_after"); _exact(v,("schema_version","kind","records"))
+    type(v["records"]) is list or _bad(); [_exact(r,("stage","argv_b64","cwd_b64","exit_code","trace_first_sequence","trace_last_sequence")) for r in v["records"]]
+    if [r["stage"] for r in v["records"]] != list(stages): _bad()
+    for r in v["records"]: [_b64(x) for x in r["argv_b64"]] if type(r["argv_b64"]) is list else _bad(); _b64(r["cwd_b64"]); [_u(r[x]) for x in ("exit_code","trace_first_sequence","trace_last_sequence")]; r["trace_first_sequence"] <= r["trace_last_sequence"] or _bad()
+def _validate_artifact(v):
+    return ({"seed_request":_request,"source_state":_state,"trace":_trace,"command_journal":_journal}.get(v.get("kind"),lambda _: _bad())(v),_DOMAINS[v["kind"]])[1]
 def load_artifact(*, path: str, expected_kind: str) -> dict:
-    if type(path) is not str or type(expected_kind) is not str or not path or not expected_kind: raise ContractError("ARGUMENT_ERROR")
+    if type(path) is not str or type(expected_kind) is not str or not path or expected_kind not in ("seed_request","source_state","trace","command_journal"): raise ContractError("ARGUMENT_ERROR")
     try: raw = open(path, "rb").read()
     except (OSError, TypeError): raise ContractError("DESCRIPTOR_NOT_FOUND") from None
     try: value = json.loads(raw.decode(), object_pairs_hook=_pairs)
     except UnicodeDecodeError: raise ContractError("DESCRIPTOR_INVALID_UTF8") from None
     except json.JSONDecodeError: raise ContractError("DESCRIPTOR_SCHEMA_INVALID") from None
+    if type(value) is not dict or type(value.get("schema_version")) is not int: _bad()
+    if value["schema_version"] != 1: raise ContractError("UNSUPPORTED_SCHEMA_VERSION")
     _guard(value)
     if not isinstance(value, dict) or value.get("kind") != expected_kind: raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
+    _validate_artifact(value)
     return value
diff --git a/common/tests/test_seed_contract_runtime.py b/common/tests/test_seed_contract_runtime.py
index 0718739..b20c2b3 100644
--- a/common/tests/test_seed_contract_runtime.py
+++ b/common/tests/test_seed_contract_runtime.py
@@ -14,22 +14,41 @@ def core():
     assert ContractError(7).code == "ARGUMENT_ERROR"
     assert canonical_bytes(value={"b":"雪","a":1}) == b'{"a":1,"b":"\xe9\x9b\xaa"}' == canonical_bytes(value={"a":1,"b":"雪"})
     for n in (-(2**53-1), 2**53-1): canonical_bytes(value=n)
     for n in (-2**53, 2**53): bad(lambda n=n: canonical_bytes(value=n), "DESCRIPTOR_SCHEMA_INVALID")
     for s in ("\ud800", "\udc00"): bad(lambda s=s: canonical_bytes(value=s), "DESCRIPTOR_SCHEMA_INVALID")
     for value in ((1,2), {1:"v"}, {1:"a","1":"b"}): bad(lambda value=value: canonical_bytes(value=value), "DESCRIPTOR_SCHEMA_INVALID")
     for fn in (canonical_bytes, lambda **kw: domain_digest(domain_ascii="test/v1\0", **kw)): bad(lambda fn=fn: fn(value={"\ue000":1,"\U00010000":2}), "DESCRIPTOR_SCHEMA_INVALID")
     with tempfile.TemporaryDirectory() as directory:
         p = Path(directory) / "seed.json"
         for raw, code in ((b'{"kind":"seed","kind":"seed"}', "DUPLICATE_JSON_KEY"), (b'{"kind":"seed","x":"\\ud800"}', "DESCRIPTOR_SCHEMA_INVALID")):
-            p.write_bytes(raw); bad(lambda: load_artifact(path=str(p), expected_kind="seed"), code)
+            p.write_bytes(raw); bad(lambda: load_artifact(path=str(p), expected_kind="seed_request"), code)
     for kwargs in ({"path":None,"expected_kind":"seed"}, {"path":"missing","expected_kind":1}): bad(lambda kwargs=kwargs: load_artifact(**kwargs), "ARGUMENT_ERROR")
     assert domain_digest(domain_ascii="test/v1\0", value={"a":1}) == hashlib.sha256(b'test/v1\0{"a":1}').hexdigest()
     for domain in (type("FauxDomain",(),{"encode":lambda *_:b"x"})(), type("ExplodingDomain",(),{"encode":lambda *_:(_ for _ in ()).throw(RuntimeError("unexpected"))})()): bad(lambda domain=domain: domain_digest(domain_ascii=domain,value={}), "ARGUMENT_ERROR")
     assert ContractError.__init__.__annotations__ == {"code":str,"return":None} and canonical_bytes.__annotations__ == {"value":object,"return":bytes} and domain_digest.__annotations__ == {"domain_ascii":str,"value":object,"return":str} and load_artifact.__annotations__ == {"path":str,"expected_kind":str,"return":dict}
 def concurrent():
     with ThreadPoolExecutor(max_workers=8) as pool: outcomes = list(pool.map(lambda _: subprocess.run([sys.executable, __file__, "canonical-core"], capture_output=True, text=True, env={**os.environ,"PYTHONDONTWRITEBYTECODE":"1"}), range(20)))
     assert all((r.returncode, r.stdout, r.stderr) == (0, "PASS canonical-core\n", "") for r in outcomes)
+def evidence():
+    runtime=__import__("seed_contract_runtime"); assert hasattr(runtime, "_validate_artifact"), "evidence validators missing"
+    b = lambda x: __import__("base64").b64encode(x).decode()
+    req={"schema_version":1,"kind":"seed_request","source_root":os.getcwd(),"envsetup_relpath":"build/envsetup.sh","lunch":{"target":"a","product":"b","release":"c","variant":"d"},"source_scope":{"role":"local_lk7k_product","public_aosp_baseline":False,"vendor_context":True,"platform_family":"aosp-17"},"resource_minimums":{"available_bytes":2**53-1,"available_inodes":2**53-1,"effective_memory_bytes":2**53-1,"effective_cpus":2**53-1},"estimated_disk_upper_bound_bytes":2**53-1}
+    entry={"path_b64":b(b"a"),"status_record_b64":b(b"x"),"entry_kind":"regular","mode":2**53-1,"content_sha256":"0"*64,"symlink_target_sha256":None}; state={"schema_version":1,"kind":"source_state","manifest_sha256":"0"*64,"projects":[{"path":"a","head":"0"*40,"status_sha256":"0"*64,"entries":[entry]}]}
+    record={"sequence":0,"process_ordinal":2**53-1,"syscall":"execve","result":-(2**53-1),"errno":"E","exec_argv_b64":[b(b"x"),b(b"x")],"paths":[{"role":"path","dirfd":None,"raw_b64":b(b"a"),"resolved_b64":b(b"a")},{"role":"path","dirfd":None,"raw_b64":b(b"a"),"resolved_b64":b(b"a")}],"address_family":None,"classification":"other"}; trace={"schema_version":1,"kind":"trace","records":[record],"counts":{"other":0,"external_network":0,"source_mutation":0,"sync_download":0,"config_query":0,"module_build":0,"package":0}}
+    stages=("manifest_before","source_state_before","namespace_probe","envsetup_lunch","manifest_after","source_state_after"); journal={"schema_version":1,"kind":"command_journal","records":[{"stage":s,"argv_b64":[b(b"x"),b(b"x")],"cwd_b64":b(b"/"),"exit_code":2**53-1,"trace_first_sequence":2**53-1,"trace_last_sequence":2**53-1} for s in stages]}
+    with tempfile.TemporaryDirectory() as d:
+        for value in (req,state,trace,journal):
+            p=Path(d)/value["kind"]; p.write_text(__import__("json").dumps(value)); assert load_artifact(path=str(p),expected_kind=value["kind"]) == value
+            domain={"seed_request":"aosp-harness/seed-request/v1\0","source_state":"aosp-harness/source-state/v1\0","trace":"aosp-harness/trace/v1\0","command_journal":"aosp-harness/command-journal/v1\0"}[value["kind"]]; assert runtime._validate_artifact(value) == domain and domain_digest(domain_ascii=domain,value=value) == hashlib.sha256(domain.encode()+canonical_bytes(value=value)).hexdigest()
+        project_domain="aosp-harness/project-source-state/v1\0"; assert runtime._project(state["projects"][0]) == project_domain and domain_digest(domain_ascii=project_domain,value=state["projects"][0]) == hashlib.sha256(project_domain.encode()+canonical_bytes(value=state["projects"][0])).hexdigest(); link=Path(d)/"source-link"; link.symlink_to(d,target_is_directory=True); bad(lambda:load_artifact(path=str(p),expected_kind="bogus"),"ARGUMENT_ERROR")
+        walk=lambda v,q=():sum(([(q,k,x)]+walk(x,q+(k,)) for k,x in v.items()),[]) if type(v)is dict else sum((walk(x,q+(i,)) for i,x in enumerate(v)),[]) if type(v)is list else []; at=lambda v,q:__import__("functools").reduce(lambda x,k:x[k],q,v)
+        for value in (req,state,trace,journal):
+            for q,k,z in walk(value):
+                for f in (lambda o,k,z:o.pop(k),lambda o,k,z:o.__setitem__("unknown",None),lambda o,k,z:o.__setitem__(k,None if z is not None else "")):
+                    x=__import__("copy").deepcopy(value); f(at(x,q),k,z); p=Path(d)/"bad"; p.write_text(__import__("json").dumps(x)); bad(lambda x=x,kind=value["kind"]:load_artifact(path=str(p),expected_kind=kind),"DESCRIPTOR_SCHEMA_INVALID")
+        for value,mutate,code in ((req,lambda x:x.update(schema_version=2,kind="trace"),"UNSUPPORTED_SCHEMA_VERSION"),(req,lambda x:x.update(schema_version=2,estimated_disk_upper_bound_bytes=1.5),"UNSUPPORTED_SCHEMA_VERSION"),(req,lambda x:x.update(kind="bogus"),"DESCRIPTOR_SCHEMA_INVALID"),(req,lambda x:x.update(source_root="/tmp/a\0b"),"DESCRIPTOR_SCHEMA_INVALID"),(req,lambda x:x["source_scope"].update(public_aosp_baseline=0),"DESCRIPTOR_SCHEMA_INVALID"),(req,lambda x:x["resource_minimums"].update(available_bytes=-1),"DESCRIPTOR_SCHEMA_INVALID"),(req,lambda x:x.update(source_root=os.getcwd()+"//"),"DESCRIPTOR_SCHEMA_INVALID"),(req,lambda x:x.update(source_root="//"+os.getcwd().lstrip("/")),"DESCRIPTOR_SCHEMA_INVALID"),(req,lambda x:x.update(source_root=str(link)),"DESCRIPTOR_SCHEMA_INVALID"),(state,lambda x:x["projects"].append(x["projects"][0]),"DESCRIPTOR_SCHEMA_INVALID"),(state,lambda x:(x["projects"].append(__import__("copy").deepcopy(x["projects"][0])),x["projects"][1].update(path="0")),"DESCRIPTOR_SCHEMA_INVALID"),(state,lambda x:x["projects"][0]["entries"].append(x["projects"][0]["entries"][0]),"DESCRIPTOR_SCHEMA_INVALID"),(state,lambda x:(x["projects"][0]["entries"].append(__import__("copy").deepcopy(x["projects"][0]["entries"][0])),x["projects"][0]["entries"][1].update(path_b64="MA==")),"DESCRIPTOR_SCHEMA_INVALID"),(state,lambda x:x["projects"][0]["entries"][0].update(path_b64="?"),"DESCRIPTOR_SCHEMA_INVALID"),(state,lambda x:x["projects"][0]["entries"][0].update(status_record_b64="?",entry_kind="bad"),"DESCRIPTOR_SCHEMA_INVALID"),(trace,lambda x:x["records"][0].update(sequence=2**53),"DESCRIPTOR_SCHEMA_INVALID"),(trace,lambda x:(x["records"].append(__import__("copy").deepcopy(x["records"][0])),x["counts"].update(other=0)),"DESCRIPTOR_SCHEMA_INVALID"),(trace,lambda x:(x["records"].append(__import__("copy").deepcopy(x["records"][0])),x["records"][0].update(sequence=1),x["counts"].update(other=0)),"DESCRIPTOR_SCHEMA_INVALID"),(trace,lambda x:x["records"][0].update(result=-(2**53),errno="E"),"DESCRIPTOR_SCHEMA_INVALID"),(trace,lambda x:x["records"][0].update(classification="bad",address_family="bad",exec_argv_b64=["?"],paths=[{"role":"bad","dirfd":None,"raw_b64":"?","resolved_b64":"?"}]),"DESCRIPTOR_SCHEMA_INVALID"),(journal,lambda x:x["records"].reverse(),"DESCRIPTOR_SCHEMA_INVALID"),(journal,lambda x:x["records"][0].update(argv_b64=["?"],cwd_b64="?"),"DESCRIPTOR_SCHEMA_INVALID"),(journal,lambda x:x.update(records=[0]),"DESCRIPTOR_SCHEMA_INVALID"),(journal,lambda x:x.update(records=[[]]),"DESCRIPTOR_SCHEMA_INVALID"),(journal,lambda x:x.update(records=[None]),"DESCRIPTOR_SCHEMA_INVALID")):
+            x=__import__("copy").deepcopy(value); mutate(x); p=Path(d)/"bad"; p.write_text(__import__("json").dumps(x)); bad(lambda x=x,kind=value["kind"]:load_artifact(path=str(p),expected_kind=kind),code)
 if __name__ == "__main__":
-    cases = {"canonical-core": core, "concurrent-core": concurrent}
-    try: cases[sys.argv[1]](); print("PASS " + sys.argv[1])
+    cases = {"canonical-core": core, "concurrent-core": concurrent, "evidence-schema": evidence}
+    try: [(cases[case](), print("PASS " + case)) for case in sys.argv[1:]]
     except (IndexError, KeyError): raise SystemExit("usage: canonical-core|concurrent-core") from None
```
