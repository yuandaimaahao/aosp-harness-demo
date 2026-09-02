# review 包 b0d0b133..3c3efcb2

## commit 列表

```
3c3efcb feat(harness): confine runtime state paths
```

## diff --stat

```
 .../closure/v1/lib/seed_contract_runtime.py        | 37 +++++++++++++++++++++-
 common/tests/test_seed_contract_runtime.py         | 17 +++++++++-
 2 files changed, 52 insertions(+), 2 deletions(-)
```

## diff

```diff
diff --git a/common/.harness/closure/v1/lib/seed_contract_runtime.py b/common/.harness/closure/v1/lib/seed_contract_runtime.py
index b1dda98..7a0fb7f 100644
--- a/common/.harness/closure/v1/lib/seed_contract_runtime.py
+++ b/common/.harness/closure/v1/lib/seed_contract_runtime.py
@@ -1,11 +1,11 @@
-import base64, hashlib, json, os, re; from urllib.parse import parse_qsl,urlsplit; RUNTIME_ABI, _SAFE = "seed-contract-runtime/v1", 2**53-1
+import base64, hashlib, json, os, re; from types import MappingProxyType; from urllib.parse import parse_qsl,urlsplit; RUNTIME_ABI, _SAFE = "seed-contract-runtime/v1", 2**53-1
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
@@ -16,20 +16,55 @@ def _guard(value):
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
+def _open_dirs(path, make=False):
+    fd=os.open("/",os.O_RDONLY|os.O_DIRECTORY)
+    try:
+        for part in path.split("/")[1:]:
+            try: nxt=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd)
+            except FileNotFoundError:
+                if not make: raise
+                os.mkdir(part,0o700,dir_fd=fd); nxt=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd)
+            os.close(fd); fd=nxt
+        return fd
+    except BaseException: os.close(fd); raise
+def _contained(path, root): return root=="/" or path==root or path.startswith(root+"/")
+def validate_state_paths(*, state_dir: str, out_ref: str | None, artifact_store: str, forbidden_roots: tuple[str, ...]):
+    if type(state_dir) is not str or type(artifact_store) is not str or type(forbidden_roots) is not tuple or out_ref is not None and type(out_ref) is not str: raise ContractError("ARGUMENT_ERROR")
+    state=state_dir; store=os.path.join(state,"artifacts/v1")
+    try:
+        if not os.path.isabs(state) or state.startswith("~") or state!=os.path.normpath(state) or state!=os.path.realpath(state) or artifact_store!=store or not os.access(state,os.W_OK|os.X_OK): raise OSError
+        fd=_open_dirs(state); os.close(fd)
+        roots=tuple(os.path.realpath(x) for x in forbidden_roots)
+        if any(_contained(state,x) or _contained(store,x) for x in roots): raise OSError
+        fd=_open_dirs(os.path.join(store,"sha256"),True); os.close(fd)
+    except (OSError,TypeError,ValueError): raise ContractError("STATE_DIR_CONTRACT") from None
+    if out_ref is None: return MappingProxyType({"state_dir":state,"artifact_store":store,"object_dir":store+"/sha256","out_ref":None,"ref_parent":None,"lock_path":None})
+    try:
+        if not os.path.isabs(out_ref) or out_ref!=os.path.normpath(out_ref) or not _contained(out_ref,state) or out_ref==state or any(_contained(out_ref,x) for x in roots): raise OSError
+        parent,leaf=os.path.dirname(out_ref),os.path.basename(out_ref)
+        if not leaf or leaf in (".",".."): raise OSError
+        fd=_open_dirs(parent,True)
+        try:
+            leaf_fd=os.open(leaf,os.O_RDONLY|os.O_NOFOLLOW,dir_fd=fd); stat=os.fstat(leaf_fd); os.close(leaf_fd)
+            if not __import__("stat").S_ISREG(stat.st_mode): raise OSError
+        except FileNotFoundError: pass
+        finally: os.close(fd)
+    except (OSError,TypeError,ValueError): raise ContractError("OUT_REF_CONTRACT") from None
+    return MappingProxyType({"state_dir":state,"artifact_store":store,"object_dir":store+"/sha256","out_ref":out_ref,"ref_parent":parent,"lock_path":out_ref+".lock"})
 _DOMAINS={"seed_request":"aosp-harness/seed-request/v1\0","project_source_state":"aosp-harness/project-source-state/v1\0","source_state":"aosp-harness/source-state/v1\0","trace":"aosp-harness/trace/v1\0","command_journal":"aosp-harness/command-journal/v1\0","seed_content":"aosp-harness/seed-content/v1\0","seed_identity":"aosp-harness/seed-identity/v1\0","seed":"aosp-harness/seed-artifact/v1\0","terminal_report":"aosp-harness/terminal-report/v1\0"}
 def _bad(): raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
 def _exact(v, keys): _bad() if type(v) is not dict or set(v) != set(keys) else None
 def _u(v): _bad() if type(v) is not int or not 0 <= v <= _SAFE else None
 def _i(v): _bad() if type(v) is not int or not -_SAFE <= v <= _SAFE else None
 def _text(v, ascii=False): _bad() if type(v) is not str or not v or ascii and not v.isascii() else None
 def _hex(v, lengths=(64,)): _bad() if type(v) is not str or len(v) not in lengths or any(c not in "0123456789abcdef" for c in v) else None
 def _b64(v):
     try:
         if type(v) is not str or base64.b64encode(base64.b64decode(v, validate=True)).decode() != v: _bad()
diff --git a/common/tests/test_seed_contract_runtime.py b/common/tests/test_seed_contract_runtime.py
index afee81e..836a9de 100644
--- a/common/tests/test_seed_contract_runtime.py
+++ b/common/tests/test_seed_contract_runtime.py
@@ -86,14 +86,29 @@ def seed():
         p=Path(d)/"seed.json"; p.write_text(__import__("json").dumps(seed)); link=Path(d)/"repo"; link.symlink_to(p); launcher=copy.deepcopy(seed); launcher["tools"]["repo_launcher_path"]=str(link); finish(launcher); assert load_artifact(path=str(p),expected_kind="seed")==seed and runtime._validate_artifact(launcher)=="aosp-harness/seed-artifact/v1\0"
 def terminal():
     runtime=__import__("seed_contract_runtime"); copy=__import__("copy"); fixture=Path(__file__).parent/"fixtures/aosp17-services/seed.golden.json"; golden=load_artifact(path=str(fixture),expected_kind="seed"); assert fixture.read_bytes()==runtime._object_bytes(golden) and golden["evidence_class"]=="fixture_only" and golden["source_scope"]["role"]=="public_aosp17_cuttlefish" and domain_digest(domain_ascii="aosp-harness/seed-artifact/v1\0",value=golden)=="07ed847af333505342d14f49d28982f6bcc307984dbf928cd762b49c7872587f"
     reasons=("SOURCE_ROOT_UNAVAILABLE","REPO_METADATA_UNAVAILABLE","ENVSETUP_UNAVAILABLE","REPO_CLIENT_UNAVAILABLE","WORKTREE_ENUM_UNAVAILABLE","RESOURCE_DISK","RESOURCE_INODE","RESOURCE_MEMORY","RESOURCE_CPU","NETWORK_NAMESPACE_UNAVAILABLE","TRACE_UNAVAILABLE","LUNCH_FAILED","FORBIDDEN_EXECUTION","SOURCE_MUTATION","SOURCE_CHANGED"); report={"schema_version":1,"kind":"terminal_report","request_digest":"0"*64,"primary_reason":reasons[0],"failed_checks":[reasons[0],reasons[10]],"completed_observation_digests":{"source_state":None,"trace":"0"*64,"command_journal":None},"summary_lines":[reasons[0],reasons[10],reasons[0]]}; assert runtime._validate_artifact(report)=="aosp-harness/terminal-report/v1\0" and runtime._object_bytes(report)==canonical_bytes(value=report)+b"\n" and domain_digest(domain_ascii="aosp-harness/terminal-report/v1\0",value=report)=="83ffe86b71affe2165201193c163c9e531ed08b6a3ff76a56db8e1b625bd4268"; evidence(); seed()
     for key in report: changed=copy.deepcopy(report); changed.pop(key); bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID"); changed=copy.deepcopy(report); changed[key]={}; bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID"); changed=copy.deepcopy(report); changed[key]=None; bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID")
     for key in report["completed_observation_digests"]: changed=copy.deepcopy(report); changed["completed_observation_digests"].pop(key); bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID"); changed=copy.deepcopy(report); changed["completed_observation_digests"][key]=[]; bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID"); changed=copy.deepcopy(report); changed["completed_observation_digests"][key]=None; runtime._validate_artifact(changed)
     for reason in reasons: changed=copy.deepcopy(report); changed.update(primary_reason=reason,failed_checks=[reason],summary_lines=[reason]); runtime._validate_artifact(changed)
     for lines in ([reasons[10],reasons[0],reasons[10]],[reasons[0]]*120): changed=copy.deepcopy(report); changed["summary_lines"]=lines; runtime._validate_artifact(changed)
     for fn in (lambda x:x.update(failed_checks=[]),lambda x:x.update(failed_checks=["UNKNOWN"]),lambda x:x.update(failed_checks=[None]),lambda x:x.update(failed_checks=[reasons[10],reasons[0]]),lambda x:x.update(failed_checks=[reasons[0],reasons[0]]),lambda x:x.update(primary_reason=reasons[10]),lambda x:x["completed_observation_digests"].update(extra=None),lambda x:x["completed_observation_digests"].update(trace="A"*64),lambda x:x.update(summary_lines=[None]),lambda x:x.update(summary_lines=[reasons[0]]*121),lambda x:x.update(summary_lines=["alice"]),lambda x:x.update(summary_lines=["12:00:00Z"]),lambda x:x.update(summary_lines=["1788283200"]),lambda x:x.update(summary_lines=["ghp_abcdefgh"]),lambda x:x.update(summary_lines=["AKIA123"]),lambda x:x.update(summary_lines=["int main(void) { return 0; }"])): changed=copy.deepcopy(report); fn(changed); bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID")
     changed=copy.deepcopy(golden); changed["guard"]["trace_digest"]="1"*64; assert runtime._validate_artifact(changed)==runtime._DOMAINS["seed"] and changed["seed_identity_digest"]==golden["seed_identity_digest"] and domain_digest(domain_ascii=runtime._DOMAINS["seed"],value=changed)!=domain_digest(domain_ascii=runtime._DOMAINS["seed"],value=golden)
+def state_paths():
+    runtime=__import__("seed_contract_runtime")
+    with tempfile.TemporaryDirectory() as d:
+        root=Path(d); state=root/"state"; state.mkdir(); store=state/"artifacts/v1"; ref=state/"refs/new/seed"
+        p=runtime.validate_state_paths(state_dir=str(state),out_ref=str(ref),artifact_store=str(store),forbidden_roots=())
+        assert set(p)=={"state_dir","artifact_store","object_dir","out_ref","ref_parent","lock_path"} and dict(p)=={"state_dir":str(state),"artifact_store":str(store),"object_dir":str(store/"sha256"),"out_ref":str(ref),"ref_parent":str(ref.parent),"lock_path":str(ref)+".lock"}
+        try: p["state_dir"]="x"; assert False
+        except TypeError: pass
+        link=root/"link"; link.symlink_to(state); bads=(("~/state",str(store),None,(),"STATE_DIR_CONTRACT"),("state",str(store),None,(),"STATE_DIR_CONTRACT"),(str(root/"missing"),str(store),None,(),"STATE_DIR_CONTRACT"),(str(link),str(store),None,(),"STATE_DIR_CONTRACT"),(str(state),str(state/"wrong"),None,(),"STATE_DIR_CONTRACT"),(str(state),str(store),None,(str(state),),"STATE_DIR_CONTRACT"),(str(state),str(store),None,("/",),"STATE_DIR_CONTRACT"),(str(state),str(store),str(root/"escape"),(),"OUT_REF_CONTRACT"))
+        parent=state/"bad"; parent.symlink_to(root)
+        bads += ((str(state),str(store),str(parent/"leaf"),(),"OUT_REF_CONTRACT"),)
+        blocked=root/"blocked"; blocked.mkdir(); blocked.chmod(0o500)
+        bads += ((str(blocked),str(blocked/"artifacts/v1"),None,(),"STATE_DIR_CONTRACT"),)
+        for sd,st,rf,roots,code in bads: bad(lambda sd=sd,st=st,rf=rf,roots=roots:runtime.validate_state_paths(state_dir=sd,out_ref=rf,artifact_store=st,forbidden_roots=roots),code)
+        blocked.chmod(0o700)
 if __name__ == "__main__":
-    cases = {"canonical-core": core, "concurrent-core": concurrent, "evidence-schema": evidence,"seed-schema":seed,"terminal-golden":terminal}
+    cases = {"canonical-core": core, "concurrent-core": concurrent, "evidence-schema": evidence,"seed-schema":seed,"terminal-golden":terminal,"state-paths":state_paths}
     try: [(cases[case](), print("PASS " + case)) for case in sys.argv[1:]]
     except (IndexError, KeyError): raise SystemExit("usage: canonical-core|concurrent-core") from None
```
