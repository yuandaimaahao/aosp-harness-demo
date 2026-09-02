# review 包 c5b7bfce..e577c24a

## commit 列表

```
e577c24 fix(harness): preserve ref publish precommit state
2b9dc53 fix(harness): harden locked ref publication
abc4a8f feat(harness): atomically publish locked seed refs
```

## diff --stat

```
 .../closure/v1/lib/seed_contract_runtime.py        | 60 ++++++++++++++++++++--
 common/tests/test_seed_contract_runtime.py         | 18 ++++++-
 2 files changed, 73 insertions(+), 5 deletions(-)
```

## diff

```diff
diff --git a/common/.harness/closure/v1/lib/seed_contract_runtime.py b/common/.harness/closure/v1/lib/seed_contract_runtime.py
index bfddc50..06ff458 100644
--- a/common/.harness/closure/v1/lib/seed_contract_runtime.py
+++ b/common/.harness/closure/v1/lib/seed_contract_runtime.py
@@ -21,21 +21,24 @@ def _guard(value):
 def canonical_bytes(*, value: object) -> bytes:
     _guard(value); return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
 def domain_digest(*, domain_ascii: str, value: object) -> str:
     if type(domain_ascii) is not str or not domain_ascii.isascii(): raise ContractError("ARGUMENT_ERROR")
     return hashlib.sha256(domain_ascii.encode() + canonical_bytes(value=value)).hexdigest()
 _P=os.O_PATH|os.O_DIRECTORY|os.O_NOFOLLOW
 def _same(fd,path):
     other=os.open(path,_P)
     try: return os.fstat(fd).st_dev==os.fstat(other).st_dev and os.fstat(fd).st_ino==os.fstat(other).st_ino
     finally: os.close(other)
-def _drop(nodes): [os.close(fd) for fd,_ in nodes]
+def _close(fd):
+    try: os.close(fd)
+    except OSError: pass
+def _drop(nodes): [_close(fd) for fd,_ in nodes]
 def _clean(made):
     for fd,name in reversed(made):
         try: os.rmdir(name,dir_fd=fd)
         except OSError: pass
 def _walk(path,make=False):
     nodes=[]; made=[]
     try:
         nodes=[(os.open("/",_P),"/")]
         for name in path.split("/")[1:]:
             parent,base=nodes[-1]; _same(parent,base) or (_ for _ in ()).throw(OSError()) ; child_path=base.rstrip("/")+"/"+name
@@ -231,22 +234,22 @@ def resolve_ref(*, state_dir: str, ref: str, artifact_store: str, forbidden_root
         evidence=_closure(primary,values) if expected=="seed" else None; require_public_real and not _validate_public_real(primary,evidence) and (_ for _ in ()).throw(ContractError("PUBLIC_SCOPE_REQUIRED")); return primary
     except ContractError: raise
     except (OSError,TypeError,ValueError,KeyError): raise ContractError("REF_CORRUPT" if locked else "OUT_REF_CONTRACT") from None
     finally:
         if lock is not None:
             try: fcntl.flock(lock,fcntl.LOCK_UN)
             except OSError: pass
         for fd in ([lock] if lock is not None else [])+[fd for fd,_ in object_nodes+nodes]:
             try: os.close(fd)
             except OSError: pass
-def publish_object(*, state_dir: str, artifact_store: str, object_kind: str, payload: dict, forbidden_roots: tuple[str, ...], fault_point: str | None = None) -> dict:
-    if type(state_dir) is not str or type(artifact_store) is not str or type(object_kind) is not str or object_kind not in ("source_state","trace","command_journal") or type(payload) is not dict or type(forbidden_roots) is not tuple or fault_point not in (None,"OBJECT_LINK","OBJECT_DIR_FSYNC") or any(type(x)is not str or "\0" in x or not os.path.isabs(x) or x!=os.path.normpath(x) or x!=os.path.realpath(x) for x in forbidden_roots): raise ContractError("ARGUMENT_ERROR")
+def _publish_object(*, state_dir: str, artifact_store: str, object_kind: str, payload: dict, forbidden_roots: tuple[str, ...], fault_point: str | None = None, _output: bool = False) -> dict:
+    if type(state_dir) is not str or type(artifact_store) is not str or type(object_kind) is not str or object_kind not in (("source_state","trace","command_journal","seed","terminal_report") if _output else ("source_state","trace","command_journal")) or type(payload) is not dict or type(forbidden_roots) is not tuple or fault_point not in (None,"OBJECT_LINK","OBJECT_DIR_FSYNC") or any(type(x)is not str or "\0" in x or not os.path.isabs(x) or x!=os.path.normpath(x) or x!=os.path.realpath(x) for x in forbidden_roots): raise ContractError("ARGUMENT_ERROR")
     domain=_validate_artifact(payload); payload["kind"]==object_kind or (_ for _ in ()).throw(ContractError("ARGUMENT_ERROR")); data=_object_bytes(payload); digest=hashlib.sha256(domain.encode()+data[:-1]).hexdigest(); paths=validate_state_paths(state_dir=state_dir,out_ref=None,artifact_store=artifact_store,forbidden_roots=forbidden_roots); nodes=[]; linked=False; fd=None
     try:
         nodes,_=_walk(paths["object_dir"]); fd=os.open(".",os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=nodes[-1][0])
         def read(name):
             try: probe=os.open(name,os.O_PATH|os.O_NOFOLLOW,dir_fd=fd)
             except FileNotFoundError: return None
             try: stat=os.fstat(probe)
             finally: os.close(probe)
             if not __import__("stat").S_ISREG(stat.st_mode) or __import__("stat").S_IMODE(stat.st_mode)!=0o444: raise ContractError("DIGEST_COLLISION")
             file=os.open(name,os.O_RDONLY|os.O_NOFOLLOW,dir_fd=fd)
@@ -267,12 +270,61 @@ def publish_object(*, state_dir: str, artifact_store: str, object_kind: str, pay
             if fault_point == "OBJECT_DIR_FSYNC": raise ContractError("PUBLISH_OBJECT_ORPHANED")
             os.fsync(fd); return {"digest":digest,"object_path":paths["object_dir"]+"/"+digest}
         finally: os.close(file)
     except ContractError: raise
     except OSError as error:
         try:
             if error.errno==17 and read(digest): os.fsync(fd); return {"digest":digest,"object_path":paths["object_dir"]+"/"+digest}
         except OSError: pass
         raise ContractError("PUBLISH_OBJECT_ORPHANED" if linked else "PUBLISH_PRECOMMIT_FAILED") from None
     finally:
-        if fd is not None: os.close(fd)
+        if fd is not None: _close(fd)
         _drop(nodes)
+def publish_object(*, state_dir: str, artifact_store: str, object_kind: str, payload: dict, forbidden_roots: tuple[str, ...], fault_point: str | None = None) -> dict: return _publish_object(state_dir=state_dir,artifact_store=artifact_store,object_kind=object_kind,payload=payload,forbidden_roots=forbidden_roots,fault_point=fault_point)
+def _lock_ref(parent_path,name):
+    nodes=[]; lock=probe=None
+    try:
+        nodes,_=_walk(parent_path,True); parent=nodes[-1][0]; leaf=name+".lock"
+        try: probe=os.open(leaf,os.O_PATH|os.O_NOFOLLOW,dir_fd=parent)
+        except FileNotFoundError:
+            try: lock=os.open(leaf,os.O_RDWR|os.O_NONBLOCK|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=parent)
+            except FileExistsError: probe=os.open(leaf,os.O_PATH|os.O_NOFOLLOW,dir_fd=parent)
+        try:
+            if probe is not None: stat=os.fstat(probe); __import__("stat").S_ISREG(stat.st_mode) and stat.st_uid==os.geteuid() and __import__("stat").S_IMODE(stat.st_mode)==0o600 or (_ for _ in ()).throw(OSError()); lock=os.open(leaf,os.O_RDWR|os.O_NONBLOCK|os.O_NOFOLLOW,dir_fd=parent); fresh=os.fstat(lock); (fresh.st_dev,fresh.st_ino)==(stat.st_dev,stat.st_ino) or (_ for _ in ()).throw(OSError())
+            os.fchmod(lock,0o600); stat=os.fstat(lock); __import__("stat").S_ISREG(stat.st_mode) and stat.st_uid==os.geteuid() and __import__("stat").S_IMODE(stat.st_mode)==0o600 or (_ for _ in ()).throw(OSError()); fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
+        finally: probe is None or os.close(probe)
+        return nodes,lock
+    except (OSError,TypeError,ValueError) as error: _drop(nodes+([(lock,"")] if lock is not None else [])); raise ContractError("REF_BUSY" if isinstance(error,BlockingIOError) else "OUT_REF_CONTRACT") from None
+def _stored(fd,digest,kind): raw=_readat(fd,digest,0o444); raw is not None or (_ for _ in ()).throw(ContractError("ARTIFACT_MISSING")); value=_artifact(raw,digest,kind) if raw is not False else False; value is not False or (_ for _ in ()).throw(ContractError("REF_CORRUPT")); return value
+def _evidence(fd,payload): needs=[("before",payload["source_state"]["before_digest"],"source_state"),("after",payload["source_state"]["after_digest"],"source_state"),("trace",payload["guard"]["trace_digest"],"trace"),("journal",payload["guard"]["command_journal_digest"],"command_journal")] if payload["kind"]=="seed" else [(k,d,k) for k,d in payload["completed_observation_digests"].items() if d is not None]; values={label:_stored(fd,digest,kind) for label,digest,kind in needs}; payload["kind"]!="seed" or _closure(payload,values); return values
+def _existing_ref(parent,name,objectfd):
+    raw=_readat(parent,name)
+    if raw is None: return None
+    raw is not False or (_ for _ in ()).throw(ContractError("REF_CORRUPT")); value=_decode(raw); type(value)is dict and set(value)=={"schema_version","kind","digest"} and type(value.get("schema_version"))is int and value["schema_version"]==1 and value.get("kind") in ("env_pass","terminal_report") and type(value.get("digest"))is str and re.fullmatch("[0-9a-f]{64}",value["digest"]) or (_ for _ in ()).throw(ContractError("REF_CORRUPT")); primary=_stored(objectfd,value["digest"],{"env_pass":"seed","terminal_report":"terminal_report"}[value["kind"]]); _evidence(objectfd,primary); return value
+def publish(*, state_dir: str, out_ref: str, artifact_store: str, object_kind: str, payload: dict, ref_kind: str, semantic_exit: int, forbidden_roots: tuple[str, ...], fault_point: str | None = None) -> dict:
+    if type(state_dir)is not str or type(out_ref)is not str or type(artifact_store)is not str or type(object_kind)is not str or type(payload)is not dict or type(ref_kind)is not str or type(semantic_exit)is not int or semantic_exit not in (0,20) or type(forbidden_roots)is not tuple or fault_point not in (None,"OBJECT_LINK","OBJECT_DIR_FSYNC","REF_RENAME","REF_DIR_FSYNC") or any(type(x)is not str or "\0" in x or not os.path.isabs(x) or x!=os.path.normpath(x) or x!=os.path.realpath(x) for x in forbidden_roots): raise ContractError("ARGUMENT_ERROR")
+    (object_kind,ref_kind) in (("seed","env_pass"),("terminal_report","terminal_report")) or (_ for _ in ()).throw(ContractError("ARGUMENT_ERROR")); (type(payload.get("kind"))is not str or payload["kind"]==object_kind) or (_ for _ in ()).throw(ContractError("ARGUMENT_ERROR")); domain=_validate_artifact(payload); payload["kind"]==object_kind or (_ for _ in ()).throw(ContractError("ARGUMENT_ERROR")); paths=validate_state_paths(state_dir=state_dir,out_ref=None,artifact_store=artifact_store,forbidden_roots=forbidden_roots); (os.path.isabs(out_ref) and out_ref==os.path.normpath(out_ref) and out_ref!=paths["state_dir"] and out_ref.startswith(paths["state_dir"]+"/") and os.path.basename(out_ref) not in ("",".","..") and not any(out_ref==x or out_ref.startswith(x+"/") for x in forbidden_roots)) or (_ for _ in ()).throw(ContractError("OUT_REF_CONTRACT")); nodes=[]; objects=[]; lock=refdir=None; temp=None; renamed=False
+    try:
+        nodes,lock=_lock_ref(os.path.dirname(out_ref),os.path.basename(out_ref)); parent=nodes[-1][0]; refdir=os.open(".",os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=parent); objects,_=_walk(paths["object_dir"]); objectfd=objects[-1][0]; _existing_ref(parent,os.path.basename(out_ref),objectfd); _evidence(objectfd,payload); result=_publish_object(state_dir=state_dir,artifact_store=artifact_store,object_kind=object_kind,payload=payload,forbidden_roots=forbidden_roots,fault_point=fault_point if fault_point in ("OBJECT_LINK","OBJECT_DIR_FSYNC") else None,_output=True)
+        try:
+            for n in os.listdir(refdir):
+                if re.fullmatch(r"\."+re.escape(os.path.basename(out_ref))+r"\.tmp\.[0-9]+\.[0-9a-f]{16}",n): p=os.open(n,os.O_PATH|os.O_NOFOLLOW,dir_fd=refdir); objects.append((p,"")); stat=os.fstat(p); _close(p); __import__("stat").S_ISREG(stat.st_mode) and __import__("stat").S_IMODE(stat.st_mode)==0o600 and os.unlink(n,dir_fd=refdir)
+        except OSError: pass
+        data=_object_bytes({"schema_version":1,"kind":ref_kind,"digest":result["digest"]}); temp="."+os.path.basename(out_ref)+".tmp."+str(os.getpid())+"."+__import__("secrets").token_hex(8); fd=os.open(temp,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=refdir)
+        try:
+            os.fchmod(fd,0o600); view=memoryview(data)
+            while view: view=view[os.write(fd,view):]
+            os.fsync(fd)
+        finally: os.close(fd)
+        os.replace(temp,os.path.basename(out_ref),src_dir_fd=refdir,dst_dir_fd=refdir); renamed=True
+        if fault_point in ("REF_RENAME","REF_DIR_FSYNC"): raise ContractError("REF_DURABILITY_UNCERTAIN")
+        os.fsync(refdir); return {"digest":result["digest"],"object_path":result["object_path"],"ref_path":out_ref,"semantic_exit":semantic_exit}
+    except ContractError: raise
+    except OSError: raise ContractError("REF_DURABILITY_UNCERTAIN" if renamed else "PUBLISH_OBJECT_ORPHANED") from None
+    finally:
+        if temp is not None and not renamed:
+            try: os.unlink(temp,dir_fd=refdir)
+            except OSError: pass
+        if lock is not None:
+            try: fcntl.flock(lock,fcntl.LOCK_UN)
+            except OSError: pass
+        _drop(objects+nodes+[(fd,"") for fd in (refdir,lock) if fd is not None])
diff --git a/common/tests/test_seed_contract_runtime.py b/common/tests/test_seed_contract_runtime.py
index 649ff7e..b90d218 100644
--- a/common/tests/test_seed_contract_runtime.py
+++ b/common/tests/test_seed_contract_runtime.py
@@ -153,14 +153,30 @@ def ref_resolve():
         snapshot=lambda:tuple(sorted((str(x.relative_to(root)),x.read_bytes() if x.is_file() else b"") for x in root.rglob("*")))
         def fails(fn,code): q=snapshot(); bad(fn,code); assert snapshot()==q
         fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=(),require_public_real=True),"PUBLIC_SCOPE_REQUIRED")
         ref.unlink(); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"ARTIFACT_MISSING"); ref.symlink_to(root/"bad"); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); ref.unlink(); os.mkfifo(ref); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); ref.unlink(); ref.write_bytes(b"["*2000+b"]"*2000); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); ref.write_bytes(json.dumps({"schema_version":True,"kind":"env_pass","digest":digest},sort_keys=True,separators=(",",":")).encode()+b"\n"); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); [(ref.write_bytes(json.dumps({"schema_version":version,"kind":"env_pass","digest":digest},sort_keys=True,separators=(",",":")).encode()+b"\n"),fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT")) for version in (False,1.5,"1")]; ref.write_bytes(canonical_bytes(value={"schema_version":1,"kind":"env_pass","digest":digest})+b"\n")
         (obj/digest).unlink(); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"ARTIFACT_MISSING"); (obj/digest).symlink_to(root/"bad"); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); (obj/digest).unlink(); put(seed); (obj/td).chmod(0o644); (obj/td).write_bytes(b"bad"); (obj/td).chmod(0o444); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); (obj/td).unlink(); os.mkfifo(obj/td); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); (obj/td).unlink(); put(trace)
         lock.chmod(0o644); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"OUT_REF_CONTRACT"); lock.chmod(0o600); old=runtime.os.geteuid; runtime.os.geteuid=lambda:-1; fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"OUT_REF_CONTRACT"); runtime.os.geteuid=old
         lock.unlink(); lock.symlink_to(root/"bad"); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"OUT_REF_CONTRACT"); lock.unlink(); os.mkfifo(lock); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"OUT_REF_CONTRACT"); lock.unlink(); sock=__import__("socket").socket(__import__("socket").AF_UNIX); sock.bind(str(lock)); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"OUT_REF_CONTRACT"); sock.close(); lock.unlink(); lock.touch(); lock.chmod(0o600)
         events=[]; oldf,oldr=runtime.fcntl.flock,runtime._readat; runtime.fcntl.flock=lambda *x:(events.append("lock"),oldf(*x))[1]; runtime._readat=lambda *x:(events.append("read"),oldr(*x))[1]; assert runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=())==seed and events.index("lock")<events.index("read"); runtime.fcntl.flock,runtime._readat=oldf,oldr
         held=os.open(lock,os.O_RDWR|os.O_NOFOLLOW); fcntl.flock(held,fcntl.LOCK_EX); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_BUSY"); fcntl.flock(held,fcntl.LOCK_UN); os.close(held); assert runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=())==seed; fails(lambda:runtime.resolve_ref(state_dir=str(root/"missing"),ref="relative",artifact_store=str(store),forbidden_roots=()),"STATE_DIR_CONTRACT"); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=(str(ref),)),"OUT_REF_CONTRACT"); unsafe=copy.deepcopy(seed); unsafe["guard"]["trace_digest"]="../../../sentinel"; unsafe_digest=put(unsafe); ref.write_bytes(canonical_bytes(value={"schema_version":1,"kind":"env_pass","digest":unsafe_digest})+b"\n"); reads=[]; oldr=runtime._readat; runtime._readat=lambda *x:(reads.append(x[1]),oldr(*x))[1]; fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); assert reads==["pass",unsafe_digest]; runtime._readat=oldr; ref.write_bytes(canonical_bytes(value={"schema_version":1,"kind":"env_pass","digest":digest})+b"\n"); before=len(os.listdir("/proc/self/fd")); oldf=runtime.fcntl.flock; runtime.fcntl.flock=lambda fd,op:(_ for _ in ()).throw(OSError(5,"unlock")) if op==fcntl.LOCK_UN else oldf(fd,op); assert runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=())==seed and len(os.listdir("/proc/self/fd"))==before; runtime.fcntl.flock=oldf; reads=[]; oldr,oldf=runtime._readat,runtime.fcntl.flock; runtime._readat=lambda *x:(reads.append(x[1]),oldr(*x))[1]; runtime.fcntl.flock=lambda fd,op:(_ for _ in ()).throw(OSError(5,"flock")) if op==fcntl.LOCK_EX|fcntl.LOCK_NB else oldf(fd,op); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"OUT_REF_CONTRACT"); assert reads==[]; runtime._readat,runtime.fcntl.flock=oldr,oldf
         terminal={"schema_version":1,"kind":"terminal_report","request_digest":h,"primary_reason":"SOURCE_ROOT_UNAVAILABLE","failed_checks":["SOURCE_ROOT_UNAVAILABLE"],"completed_observation_digests":{"source_state":sd,"trace":td,"command_journal":jd},"summary_lines":["SOURCE_ROOT_UNAVAILABLE"]}; terminal_digest=put(terminal); ref.write_bytes(canonical_bytes(value={"schema_version":1,"kind":"terminal_report","digest":terminal_digest})+b"\n"); assert runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=())==terminal; badterminal=copy.deepcopy(terminal); badterminal["failed_checks"]=[]; bad_digest=put(badterminal); ref.write_bytes(canonical_bytes(value={"schema_version":1,"kind":"terminal_report","digest":bad_digest})+b"\n"); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); badterminal=copy.deepcopy(terminal); badterminal["completed_observation_digests"]["trace"]=sd; bad_digest=put(badterminal); ref.write_bytes(canonical_bytes(value={"schema_version":1,"kind":"terminal_report","digest":bad_digest})+b"\n"); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); badjournal=copy.deepcopy(journal); badjournal["records"][3]["exit_code"]=1; journal_digest=put(badjournal); badseed=copy.deepcopy(seed); badseed["guard"]["command_journal_digest"]=journal_digest; bad_digest=put(badseed); ref.write_bytes(canonical_bytes(value={"schema_version":1,"kind":"env_pass","digest":bad_digest})+b"\n"); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); badtrace=copy.deepcopy(trace); badtrace["records"][0].update(sequence=2); trace_digest=put(badtrace); badseed=copy.deepcopy(seed); badseed["guard"]["trace_digest"]=trace_digest; bad_digest=put(badseed); ref.write_bytes(canonical_bytes(value={"schema_version":1,"kind":"env_pass","digest":bad_digest})+b"\n"); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); badtrace=copy.deepcopy(trace); badtrace["records"][0]["classification"]="external_network"; badtrace["counts"].update(other=0,external_network=1); trace_digest=put(badtrace); badseed=copy.deepcopy(seed); badseed["guard"]["trace_digest"]=trace_digest; bad_digest=put(badseed); ref.write_bytes(canonical_bytes(value={"schema_version":1,"kind":"env_pass","digest":bad_digest})+b"\n"); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); badstate=copy.deepcopy(state0); badstate["projects"]=[]; state_digest=put(badstate); badseed=copy.deepcopy(seed); badseed["source_state"].update(before_digest=state_digest,after_digest=state_digest); badseed["seed_identity_digest"]=domain_digest(domain_ascii=runtime._DOMAINS["seed_identity"],value=runtime._seed_parts(badseed)[2]); bad_digest=put(badseed); ref.write_bytes(canonical_bytes(value={"schema_version":1,"kind":"env_pass","digest":bad_digest})+b"\n"); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); public=copy.deepcopy(seed); public["evidence_class"]="real_source"; public_digest=put(public); ref.write_bytes(canonical_bytes(value={"schema_version":1,"kind":"env_pass","digest":public_digest})+b"\n"); assert runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=(),require_public_real=True)==public; local=copy.deepcopy(public); local["source_scope"]={"role":"local_lk7k_product","public_aosp_baseline":False,"vendor_context":True,"platform_family":"aosp-17"}; local["request_digest"]=domain_digest(domain_ascii=runtime._DOMAINS["seed_request"],value=runtime._seed_parts(local)[0]); local["seed_identity_digest"]=domain_digest(domain_ascii=runtime._DOMAINS["seed_identity"],value=runtime._seed_parts(local)[2]); local_digest=put(local); ref.write_bytes(canonical_bytes(value={"schema_version":1,"kind":"env_pass","digest":local_digest})+b"\n"); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=(),require_public_real=True),"PUBLIC_SCOPE_REQUIRED"); null=copy.deepcopy(terminal); null["completed_observation_digests"]={"source_state":None,"trace":None,"command_journal":None}; null_digest=put(null); ref.write_bytes(canonical_bytes(value={"schema_version":1,"kind":"terminal_report","digest":null_digest})+b"\n"); assert runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=())==null; wrong="1"*64; (obj/wrong).write_bytes(canonical_bytes(value=seed)+b"\n"); (obj/wrong).chmod(0o444); ref.write_bytes(canonical_bytes(value={"schema_version":1,"kind":"env_pass","digest":wrong})+b"\n"); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); badstate=copy.deepcopy(state0); badstate["projects"][0]["head"]="1"*40; state_digest=put(badstate); badseed=copy.deepcopy(seed); badseed["source_state"].update(before_digest=state_digest,after_digest=state_digest); badseed["seed_identity_digest"]=domain_digest(domain_ascii=runtime._DOMAINS["seed_identity"],value=runtime._seed_parts(badseed)[2]); bad_digest=put(badseed); ref.write_bytes(canonical_bytes(value={"schema_version":1,"kind":"env_pass","digest":bad_digest})+b"\n"); fails(lambda:runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=()),"REF_CORRUPT"); bad(lambda:runtime._closure({**seed,"lunch":{**seed["lunch"],"lunch_exit":1}},{"before":state0,"after":state0,"trace":trace,"journal":journal}),"REF_CORRUPT")
+def ref_publish():
+    runtime=__import__("seed_contract_runtime"); assert hasattr(runtime,"publish"),"ref publisher missing"; import concurrent.futures as F
+    with tempfile.TemporaryDirectory() as d:
+        root=Path(d); state=root/"state"; state.mkdir(); store=state/"artifacts/v1"; ref=state/"refs/pass"; make=lambda n:{"schema_version":1,"kind":"terminal_report","request_digest":str(n)*64,"primary_reason":"SOURCE_ROOT_UNAVAILABLE","failed_checks":["SOURCE_ROOT_UNAVAILABLE"],"completed_observation_digests":{"source_state":None,"trace":None,"command_journal":None},"summary_lines":["SOURCE_ROOT_UNAVAILABLE"]}; call=lambda p,**k:runtime.publish(state_dir=str(state),out_ref=str(ref),artifact_store=str(store),object_kind="terminal_report",payload=p,ref_kind="terminal_report",semantic_exit=20,forbidden_roots=(),**k); p=make(0); result=call(p); obj=Path(result["object_path"]); want=canonical_bytes(value={"schema_version":1,"kind":"terminal_report","digest":result["digest"]})+b"\n"; assert result=={"digest":result["digest"],"object_path":str(obj),"ref_path":str(ref),"semantic_exit":20} and obj.read_bytes()==canonical_bytes(value=p)+b"\n" and ref.read_bytes()==want and obj.stat().st_mode&0o777==0o444 and ref.stat().st_mode&0o777==0o600 and call(p)==result
+        sentinel=root/"sentinel"; sentinel.write_bytes(b"fixed"); before=ref.read_bytes(); p1=make(1); bad(lambda:call(p1,fault_point="OBJECT_LINK"),"PUBLISH_PRECOMMIT_FAILED"); assert ref.read_bytes()==before and not (Path(store)/"sha256"/domain_digest(domain_ascii=runtime._DOMAINS["terminal_report"],value=p1)).exists(); p2=make(2); orphan=Path(store)/"sha256"/domain_digest(domain_ascii=runtime._DOMAINS["terminal_report"],value=p2); bad(lambda:call(p2,fault_point="OBJECT_DIR_FSYNC"),"PUBLISH_OBJECT_ORPHANED"); assert orphan.read_bytes()==canonical_bytes(value=p2)+b"\n" and ref.read_bytes()==before
+        for n,point in ((3,"REF_RENAME"),(4,"REF_DIR_FSYNC")):
+            q=make(n); bad(lambda q=q,point=point:call(q,fault_point=point),"REF_DURABILITY_UNCERTAIN"); assert runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=())==q and call(q)["semantic_exit"]==20
+        state0={"schema_version":1,"kind":"source_state","manifest_sha256":"0"*64,"projects":[{"path":"a","head":"0"*40,"status_sha256":"0"*64,"entries":[]}]}; trace={"schema_version":1,"kind":"trace","records":[{"sequence":1,"process_ordinal":0,"syscall":"x","result":0,"errno":None,"exec_argv_b64":None,"paths":[],"address_family":None,"classification":"other"}],"counts":dict(other=1,external_network=0,source_mutation=0,sync_download=0,config_query=0,module_build=0,package=0)}; journal={"schema_version":1,"kind":"command_journal","records":[{"stage":x,"argv_b64":[],"cwd_b64":"","exit_code":0,"trace_first_sequence":1,"trace_last_sequence":1} for x in ("manifest_before","source_state_before","namespace_probe","envsetup_lunch","manifest_after","source_state_after")]}
+        put=lambda v:(lambda q:((Path(store)/"sha256"/q).write_bytes(canonical_bytes(value=v)+b"\n"),(Path(store)/"sha256"/q).chmod(0o444),q)[2])(domain_digest(domain_ascii=runtime._DOMAINS[v["kind"]],value=v)); sd,td,jd=put(state0),put(trace),put(journal); seed=json.loads((Path(__file__).parent/"fixtures/aosp17-services/seed.golden.json").read_text()); seed["manifest"]["projects"][0]["source_state_digest"]=domain_digest(domain_ascii=runtime._DOMAINS["project_source_state"],value=state0["projects"][0]); seed["source_state"].update(before_digest=sd,after_digest=sd); seed["guard"].update(trace_digest=td,command_journal_digest=jd); seed["seed_content_digest"]=domain_digest(domain_ascii=runtime._DOMAINS["seed_content"],value=runtime._seed_parts(seed)[1]); seed["seed_identity_digest"]=domain_digest(domain_ascii=runtime._DOMAINS["seed_identity"],value=runtime._seed_parts(seed)[2])
+        seedref=state/"refs/seed"; seeded=runtime.publish(state_dir=str(state),out_ref=str(seedref),artifact_store=str(store),object_kind="seed",payload=seed,ref_kind="env_pass",semantic_exit=0,forbidden_roots=()); assert seeded["semantic_exit"]==0 and runtime._decode(seedref.read_bytes())["kind"]=="env_pass" and runtime.resolve_ref(state_dir=str(state),ref=str(seedref),artifact_store=str(store),forbidden_roots=())==seed; stale=ref.parent/".pass.tmp.999999999.0123456789abcdef"; other=ref.parent/".other.tmp.999999999.0123456789abcdef"; stale.write_bytes(other.write_bytes(b"x") and b"x"); stale.chmod(0o600); other.chmod(0o600); call(p); assert not stale.exists() and other.exists(); coll=make(6); cpath=Path(store)/"sha256"/domain_digest(domain_ascii=runtime._DOMAINS["terminal_report"],value=coll); cstale=ref.parent/".pass.tmp.999999998.0123456789abcdef"; cpath.write_bytes(b"bad"); cpath.chmod(0o444); cstale.write_bytes(b"stale"); cstale.chmod(0o600); snap=(cpath.read_bytes(),cstale.read_bytes(),ref.read_bytes(),sentinel.read_bytes()); bad(lambda:call(coll),"DIGEST_COLLISION"); assert snap==(cpath.read_bytes(),cstale.read_bytes(),ref.read_bytes(),sentinel.read_bytes()); cpath.unlink(); cstale.unlink()
+        missing=make(5); missing["completed_observation_digests"]["trace"]="f"*64; ref.write_bytes(b"bad"); snapshot=(ref.read_bytes(),sentinel.read_bytes()); bad(lambda:call(missing),"REF_CORRUPT"); bad(lambda:runtime.publish(state_dir=str(state),out_ref=str(ref),artifact_store=str(store),object_kind="wrong",payload={},ref_kind="wrong",semantic_exit=20,forbidden_roots=()),"ARGUMENT_ERROR"); bad(lambda:call({}),"DESCRIPTOR_SCHEMA_INVALID"); bad(lambda:call({"schema_version":1,"kind":"source_state"}),"ARGUMENT_ERROR"); bad(lambda:call(seed),"ARGUMENT_ERROR"); assert (ref.read_bytes(),sentinel.read_bytes())==snapshot; ref.write_bytes(before)
+        def one(_):
+            try: return call(p)
+            except runtime.ContractError as error: return error.code
+        with F.ThreadPoolExecutor(max_workers=8) as pool: outcomes=list(pool.map(one,range(8)))
+        assert all(x==result or x=="REF_BUSY" for x in outcomes) and runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=())==p and not [x for x in root.rglob("*") if x.name.startswith(".pass.tmp.")] and sentinel.read_bytes()==b"fixed"; beforefd=len(os.listdir("/proc/self/fd")); oldc=runtime.os.close; hit=[]; runtime.os.close=lambda fd:(oldc(fd),(_ for _ in ()).throw(OSError(5,"close")))[1] if not hit and __import__("stat").S_ISDIR(os.fstat(fd).st_mode) and os.fstat(fd).st_ino==ref.parent.stat().st_ino and not runtime.fcntl.fcntl(fd,runtime.fcntl.F_GETFL)&os.O_PATH and not hit.append(1) else oldc(fd); call(p); runtime.os.close=oldc; assert hit and len(os.listdir("/proc/self/fd"))==beforefd; beforefd=len(os.listdir("/proc/self/fd")); oldc=runtime.os.close; hit=[]; runtime.os.close=lambda fd:(oldc(fd),(_ for _ in ()).throw(OSError(5,"close")))[1] if not hit and __import__("stat").S_ISDIR(os.fstat(fd).st_mode) and os.fstat(fd).st_ino==obj.parent.stat().st_ino and not runtime.fcntl.fcntl(fd,runtime.fcntl.F_GETFL)&os.O_PATH and not hit.append(1) else oldc(fd); call(p); runtime.os.close=oldc; assert hit and len(os.listdir("/proc/self/fd"))==beforefd; stale=ref.parent/".pass.tmp.999999997.0123456789abcdef"; stale.write_bytes(b"x"); stale.chmod(0o600); beforefd=len(os.listdir("/proc/self/fd")); oldf=runtime.os.fstat; hit=[]; runtime.os.fstat=lambda fd:(_ for _ in ()).throw(OSError(5,"fstat")) if not hit and runtime.fcntl.fcntl(fd,runtime.fcntl.F_GETFL)&os.O_PATH and oldf(fd).st_ino==stale.stat().st_ino and not hit.append(1) else oldf(fd); call(p); runtime.os.fstat=oldf; assert hit and len(os.listdir("/proc/self/fd"))==beforefd; stale.unlink()
 if __name__ == "__main__":
-    cases = {"canonical-core": core, "concurrent-core": concurrent, "evidence-schema": evidence,"seed-schema":seed,"terminal-golden":terminal,"state-paths":state_paths,"store-object":store_object,"ref-resolve":ref_resolve}
+    cases = {"canonical-core": core, "concurrent-core": concurrent, "evidence-schema": evidence,"seed-schema":seed,"terminal-golden":terminal,"state-paths":state_paths,"store-object":store_object,"ref-resolve":ref_resolve,"ref-publish":ref_publish}
     try: [(cases[case](), print("PASS " + case)) for case in sys.argv[1:]]
     except (IndexError, KeyError): raise SystemExit("usage: canonical-core|concurrent-core") from None
```
