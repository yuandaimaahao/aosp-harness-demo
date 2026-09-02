# review 包 b0d0b133..a01b436d

## commit 列表

```
a01b436 test(harness): bound hostile path rename handling
349fb43 fix(harness): fail closed on state races
79fec29 fix(harness): harden state path validation
3c3efcb feat(harness): confine runtime state paths
```

## diff --stat

```
 .../closure/v1/lib/seed_contract_runtime.py        | 50 +++++++++++++++++++++-
 common/tests/test_seed_contract_runtime.py         | 17 +++++++-
 2 files changed, 65 insertions(+), 2 deletions(-)
```

## diff

```diff
diff --git a/common/.harness/closure/v1/lib/seed_contract_runtime.py b/common/.harness/closure/v1/lib/seed_contract_runtime.py
index b1dda98..a0761f0 100644
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
@@ -16,20 +16,68 @@ def _guard(value):
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
+_P=os.O_PATH|os.O_DIRECTORY|os.O_NOFOLLOW
+def _same(fd,path):
+    other=os.open(path,_P)
+    try: return os.fstat(fd).st_dev==os.fstat(other).st_dev and os.fstat(fd).st_ino==os.fstat(other).st_ino
+    finally: os.close(other)
+def _drop(nodes): [os.close(fd) for fd,_ in nodes]
+def _clean(made):
+    for fd,name in reversed(made):
+        try: os.rmdir(name,dir_fd=fd)
+        except OSError: pass
+def _walk(path,make=False):
+    nodes=[]; made=[]
+    try:
+        nodes=[(os.open("/",_P),"/")]
+        for name in path.split("/")[1:]:
+            parent,base=nodes[-1]; _same(parent,base) or (_ for _ in ()).throw(OSError()) ; child_path=base.rstrip("/")+"/"+name
+            try: child=os.open(name,_P,dir_fd=parent)
+            except FileNotFoundError:
+                if not make: raise
+                os.mkdir(name,0o700,dir_fd=parent); made.append((parent,name)); child=os.open(name,_P,dir_fd=parent)
+            nodes.append((child,child_path)); (_same(parent,base) and _same(child,child_path)) or (_ for _ in ()).throw(OSError())
+        return nodes,made
+    except BaseException: _clean(made); _drop(nodes); raise
+def validate_state_paths(*, state_dir: str, out_ref: str | None, artifact_store: str, forbidden_roots: tuple[str, ...]):
+    if type(state_dir) is not str or type(artifact_store) is not str or type(forbidden_roots) is not tuple or out_ref is not None and type(out_ref) is not str or any(type(x)is not str or "\0" in x or not os.path.isabs(x) or x!=os.path.normpath(x) or x!=os.path.realpath(x) for x in forbidden_roots): raise ContractError("ARGUMENT_ERROR")
+    state=state_dir; store=os.path.join(state,"artifacts/v1"); sd=od=rd=made=[]
+    try:
+        if not os.path.isabs(state) or state.startswith("~") or state!=os.path.normpath(state) or state!=os.path.realpath(state) or artifact_store!=store or not os.access(state,os.W_OK|os.X_OK): raise OSError
+        if any(x=="/" or state==x or state.startswith(x+"/") or store==x or store.startswith(x+"/") for x in forbidden_roots): raise OSError
+        sd,_=_walk(state); od,made=_walk(store+"/sha256",True)
+        if not all(_same(fd,path) for fd,path in sd+od): raise OSError
+    except (OSError,TypeError,ValueError): _clean(made); _drop(od); _drop(sd); raise ContractError("STATE_DIR_CONTRACT") from None
+    if out_ref is None: _drop(od); _drop(sd); return MappingProxyType({"state_dir":state,"artifact_store":store,"object_dir":store+"/sha256","out_ref":None,"ref_parent":None,"lock_path":None})
+    try:
+        if not os.path.isabs(out_ref) or out_ref!=os.path.normpath(out_ref) or not(state!=out_ref and out_ref.startswith(state+"/")) or any(x=="/" or out_ref==x or out_ref.startswith(x+"/") for x in forbidden_roots): raise OSError
+        parent,leaf=os.path.dirname(out_ref),os.path.basename(out_ref)
+        if not leaf or leaf in (".",".."): raise OSError
+        rd,rmade=_walk(parent,True); made+=rmade
+        try: mode=os.stat(leaf,dir_fd=rd[-1][0],follow_symlinks=False).st_mode
+        except FileNotFoundError: mode=0
+        if mode and not __import__("stat").S_ISREG(mode) or not all(_same(fd,path) for fd,path in sd+od+rd): raise OSError
+    except ContractError: _clean(made); _drop(rd); _drop(od); _drop(sd); raise
+    except (OSError,TypeError,ValueError):
+        try: changed=not all(_same(fd,path) for fd,path in sd+od)
+        except OSError: changed=True
+        _clean(made); _drop(rd); _drop(od); _drop(sd); raise ContractError("STATE_DIR_CONTRACT" if changed else "OUT_REF_CONTRACT") from None
+    _drop(rd); _drop(od); _drop(sd)
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
index afee81e..350809f 100644
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
+        link=root/"link"; link.symlink_to(state); sibling=root/"statex"; sibling.mkdir(); assert runtime.validate_state_paths(state_dir=str(state),out_ref=None,artifact_store=str(store),forbidden_roots=(str(sibling),))["out_ref"] is None; bads=(("~/state",str(store),None,(),"STATE_DIR_CONTRACT"),("state",str(store),None,(),"STATE_DIR_CONTRACT"),(str(root/"missing"),str(store),None,(),"STATE_DIR_CONTRACT"),(str(link),str(store),None,(),"STATE_DIR_CONTRACT"),(str(state),str(state/"wrong"),None,(),"STATE_DIR_CONTRACT"),(str(state),str(store),None,(str(state),),"STATE_DIR_CONTRACT"),(str(state),str(store),None,("/",),"STATE_DIR_CONTRACT"),(str(state),str(store),None,(123,),"ARGUMENT_ERROR"),(str(state),str(store),None,(b"/tmp",),"ARGUMENT_ERROR"),(str(state),str(store),None,("relative",),"ARGUMENT_ERROR"),(str(state),str(store),str(state/"forbidden"),(str(state/"forbidden"),),"OUT_REF_CONTRACT"),(str(state),str(store),str(root/"escape"),(),"OUT_REF_CONTRACT"))
+        parent=state/"bad"; parent.symlink_to(root); regular=state/"refs/regular"; regular.touch(); assert runtime.validate_state_paths(state_dir=str(state),out_ref=str(regular),artifact_store=str(store),forbidden_roots=())["out_ref"]==str(regular); fifo=state/"refs/fifo"; os.mkfifo(fifo); probe="import sys;sys.path.insert(0,"+repr(str(Path(__file__).parents[1]/".harness/closure/v1/lib"))+ ");from seed_contract_runtime import validate_state_paths;validate_state_paths(state_dir="+repr(str(state))+",out_ref="+repr(str(fifo))+",artifact_store="+repr(str(store))+",forbidden_roots=())"; run=subprocess.run([sys.executable,"-c",probe],capture_output=True,text=True,timeout=1); assert run.returncode==1 and run.stdout=="" and run.stderr.endswith("ContractError: OUT_REF_CONTRACT\n"); sock=state/"refs/sock"; q=__import__("socket").socket(__import__("socket").AF_UNIX); q.bind(str(sock)); bad(lambda:runtime.validate_state_paths(state_dir=str(state),out_ref=str(sock),artifact_store=str(store),forbidden_roots=()),"OUT_REF_CONTRACT"); q.close(); bad(lambda:runtime.validate_state_paths(state_dir=str(state),out_ref=str(regular.parent),artifact_store=str(store),forbidden_roots=()),"OUT_REF_CONTRACT"); sy=root/"store-link"; sy.mkdir(); (sy/"artifacts").symlink_to(root); bad(lambda:runtime.validate_state_paths(state_dir=str(sy),out_ref=None,artifact_store=str(sy/"artifacts/v1"),forbidden_roots=()),"STATE_DIR_CONTRACT")
+        bads += ((str(state),str(store),str(parent/"leaf"),(),"OUT_REF_CONTRACT"),)
+        race=root/"race"; race.mkdir(); artifact=race/"artifacts"; artifact.mkdir(); outside=root/"outside"; outside.mkdir(); source=artifact/"v1"; moved=outside/"leaked-v1"; old,oldr=runtime.os.open,runtime.os.rmdir; hit=[]; runtime.os.open=lambda n,f,m=0o777,dir_fd=None:(os.rename(source,moved) if n=="v1" and not hit and source.exists() and not hit.append(n) else None) or old(n,f,m,dir_fd=dir_fd); runtime.os.rmdir=lambda n,dir_fd=None:(hit.append("rmdir:"+n),oldr(n,dir_fd=dir_fd))[1]; bad(lambda:runtime.validate_state_paths(state_dir=str(race),out_ref=None,artifact_store=str(source),forbidden_roots=()),"STATE_DIR_CONTRACT"); runtime.os.open,runtime.os.rmdir=old,oldr; assert "v1" in hit and "rmdir:v1" in hit and moved.is_dir(); stable=root/"stable"; stable.mkdir(); stable_store=stable/"artifacts/v1"; runtime.validate_state_paths(state_dir=str(stable),out_ref=None,artifact_store=str(stable_store),forbidden_roots=()); source=stable/"refs"; moved=outside/"leaked-refs"; hit=[]; runtime.os.open=lambda n,f,m=0o777,dir_fd=None:(os.rename(source,moved) if n=="refs" and not hit and source.exists() and not hit.append(n) else None) or old(n,f,m,dir_fd=dir_fd); runtime.os.rmdir=lambda n,dir_fd=None:(hit.append("rmdir:"+n),oldr(n,dir_fd=dir_fd))[1]; bad(lambda:runtime.validate_state_paths(state_dir=str(stable),out_ref=str(source/"leaf"),artifact_store=str(stable_store),forbidden_roots=()),"OUT_REF_CONTRACT"); runtime.os.open,runtime.os.rmdir=old,oldr; assert "refs" in hit and "rmdir:refs" in hit and moved.is_dir(); blocked=root/"blocked"; blocked.mkdir(); blocked.chmod(0o500)
+        bads += ((str(blocked),str(blocked/"artifacts/v1"),None,(),"STATE_DIR_CONTRACT"),)
+        for sd,st,rf,roots,code in bads: bad(lambda sd=sd,st=st,rf=rf,roots=roots:runtime.validate_state_paths(state_dir=sd,out_ref=rf,artifact_store=st,forbidden_roots=roots),code)
+        blocked.chmod(0o700); blocked.chmod(0o300); assert runtime.validate_state_paths(state_dir=str(blocked),out_ref=None,artifact_store=str(blocked/"artifacts/v1"),forbidden_roots=())["state_dir"]==str(blocked); blocked.chmod(0o700)
 if __name__ == "__main__":
-    cases = {"canonical-core": core, "concurrent-core": concurrent, "evidence-schema": evidence,"seed-schema":seed,"terminal-golden":terminal}
+    cases = {"canonical-core": core, "concurrent-core": concurrent, "evidence-schema": evidence,"seed-schema":seed,"terminal-golden":terminal,"state-paths":state_paths}
     try: [(cases[case](), print("PASS " + case)) for case in sys.argv[1:]]
     except (IndexError, KeyError): raise SystemExit("usage: canonical-core|concurrent-core") from None
```
