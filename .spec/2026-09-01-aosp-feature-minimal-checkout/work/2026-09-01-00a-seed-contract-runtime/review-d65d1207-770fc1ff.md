# review 包 d65d1207..770fc1ff

## commit 列表

```
770fc1f fix(harness): translate object race recheck errors
```

## diff --stat

```
 common/.harness/closure/v1/lib/seed_contract_runtime.py |  4 +++-
 common/tests/test_seed_contract_runtime.py              | 15 +++++++++++----
 2 files changed, 14 insertions(+), 5 deletions(-)
```

## diff

```diff
diff --git a/common/.harness/closure/v1/lib/seed_contract_runtime.py b/common/.harness/closure/v1/lib/seed_contract_runtime.py
index d049b2a..5d4e797 100644
--- a/common/.harness/closure/v1/lib/seed_contract_runtime.py
+++ b/common/.harness/closure/v1/lib/seed_contract_runtime.py
@@ -201,15 +201,17 @@ def publish_object(*, state_dir: str, artifact_store: str, object_kind: str, pay
             os.fchmod(file,0o600); view=memoryview(data)
             while view: view=view[os.write(file,view):]
             os.fsync(file); os.fchmod(file,0o444); os.fsync(file)
             if fault_point == "OBJECT_LINK": raise ContractError("PUBLISH_PRECOMMIT_FAILED")
             c=__import__("ctypes"); link=c.CDLL(None,use_errno=True).linkat; result=link(file,b"",fd,digest.encode(),0x1000); result and c.get_errno()==2 and (result:=link(-100,f"/proc/self/fd/{file}".encode(),fd,digest.encode(),0x400)); result==0 or (_ for _ in ()).throw(OSError(c.get_errno(),"linkat")); linked=True
             if fault_point == "OBJECT_DIR_FSYNC": raise ContractError("PUBLISH_OBJECT_ORPHANED")
             os.fsync(fd); return {"digest":digest,"object_path":paths["object_dir"]+"/"+digest}
         finally: os.close(file)
     except ContractError: raise
     except OSError as error:
-        if error.errno==17 and read(digest): os.fsync(fd); return {"digest":digest,"object_path":paths["object_dir"]+"/"+digest}
+        try:
+            if error.errno==17 and read(digest): os.fsync(fd); return {"digest":digest,"object_path":paths["object_dir"]+"/"+digest}
+        except OSError: pass
         raise ContractError("PUBLISH_OBJECT_ORPHANED" if linked else "PUBLISH_PRECOMMIT_FAILED") from None
     finally:
         if fd is not None: os.close(fd)
         _drop(nodes)
diff --git a/common/tests/test_seed_contract_runtime.py b/common/tests/test_seed_contract_runtime.py
index 53e2afc..1627e98 100644
--- a/common/tests/test_seed_contract_runtime.py
+++ b/common/tests/test_seed_contract_runtime.py
@@ -106,31 +106,38 @@ def state_paths():
         bads += ((str(state),str(store),str(parent/"leaf"),(),"OUT_REF_CONTRACT"),(str(sy),str(sy/"artifacts/v1"),None,(),"STATE_DIR_CONTRACT"))
         race=root/"race"; race.mkdir(); artifact=race/"artifacts"; artifact.mkdir(); outside=root/"outside"; outside.mkdir(); source=artifact/"v1"; moved=outside/"leaked-v1"; old,oldr=runtime.os.open,runtime.os.rmdir; hit=[]; runtime.os.open=lambda n,f,m=0o777,dir_fd=None:(os.rename(source,moved) if n=="v1" and not hit and source.exists() and not hit.append(n) else None) or old(n,f,m,dir_fd=dir_fd); runtime.os.rmdir=lambda n,dir_fd=None:(hit.append("rmdir:"+n),oldr(n,dir_fd=dir_fd))[1]; bad(lambda:runtime.validate_state_paths(state_dir=str(race),out_ref=None,artifact_store=str(source),forbidden_roots=()),"STATE_DIR_CONTRACT"); runtime.os.open,runtime.os.rmdir=old,oldr; assert "v1" in hit and "rmdir:v1" in hit and moved.is_dir(); stable=root/"stable"; stable.mkdir(); stable_store=stable/"artifacts/v1"; runtime.validate_state_paths(state_dir=str(stable),out_ref=None,artifact_store=str(stable_store),forbidden_roots=()); source=stable/"refs"; moved=outside/"leaked-refs"; hit=[]; runtime.os.open=lambda n,f,m=0o777,dir_fd=None:(os.rename(source,moved) if n=="refs" and not hit and source.exists() and not hit.append(n) else None) or old(n,f,m,dir_fd=dir_fd); runtime.os.rmdir=lambda n,dir_fd=None:(hit.append("rmdir:"+n),oldr(n,dir_fd=dir_fd))[1]; bad(lambda:runtime.validate_state_paths(state_dir=str(stable),out_ref=str(source/"leaf"),artifact_store=str(stable_store),forbidden_roots=()),"OUT_REF_CONTRACT"); runtime.os.open,runtime.os.rmdir=old,oldr; assert "refs" in hit and "rmdir:refs" in hit and moved.is_dir(); blocked=root/"blocked"; blocked.mkdir(); blocked.chmod(0o500)
         bads += ((str(blocked),str(blocked/"artifacts/v1"),None,(),"STATE_DIR_CONTRACT"),)
         for sd,st,rf,roots,code in bads: before=entries(root); bad(lambda sd=sd,st=st,rf=rf,roots=roots:runtime.validate_state_paths(state_dir=sd,out_ref=rf,artifact_store=st,forbidden_roots=roots),code); assert entries(root)==before
         blocked.chmod(0o700); blocked.chmod(0o300); assert runtime.validate_state_paths(state_dir=str(blocked),out_ref=None,artifact_store=str(blocked/"artifacts/v1"),forbidden_roots=())["state_dir"]==str(blocked); blocked.chmod(0o700)
 def store_object():
     runtime=__import__("seed_contract_runtime"); assert hasattr(runtime,"publish_object"),"object publisher missing"
     S=__import__("stat"); payload={"schema_version":1,"kind":"source_state","manifest_sha256":"0"*64,"projects":[]}; digest=domain_digest(domain_ascii=runtime._DOMAINS["source_state"],value=payload)
     with tempfile.TemporaryDirectory() as d:
         root=Path(d); state=root/"state"; state.mkdir(); store=state/"artifacts/v1"; outside=root/"sentinel"; outside.write_bytes(b"fixed"); temps=lambda p:[x for x in p.iterdir() if ".tmp." in x.name]; tree=lambda:tuple(sorted(str(x.relative_to(root)) for x in root.rglob("*")))
-        calls=[]; opens=[]; oldf,oldo=runtime.os.fsync,runtime.os.open; runtime.os.fsync=lambda fd:(calls.append(os.fstat(fd).st_mode),oldf(fd))[1]; runtime.os.open=lambda p,f,m=0o777,dir_fd=None:(opens.append((p,f)),oldo(p,f,m,dir_fd=dir_fd))[1]
+        calls=[]; opens=[]; C=__import__("ctypes"); links=[]; oldf,oldo,oldl=runtime.os.fsync,runtime.os.open,C.CDLL; real=oldl(None,use_errno=True).linkat; record=lambda a,r:(links.append((a[-1],r)),r)[1]; fake=lambda *a:record(a,(C.set_errno(2),-1)[1] if a[-1]==0x1000 else real(*a)); runtime.os.fsync=lambda fd:(calls.append(os.fstat(fd).st_mode),oldf(fd))[1]; runtime.os.open=lambda p,f,m=0o777,dir_fd=None:(opens.append((p,f)),oldo(p,f,m,dir_fd=dir_fd))[1]; C.CDLL=lambda *a,**k:type("L",(),{"linkat":staticmethod(fake)})()
         try:
             result=runtime.publish_object(state_dir=str(state),artifact_store=str(store),object_kind="source_state",payload=payload,forbidden_roots=())
-        finally: runtime.os.fsync,runtime.os.open=oldf,oldo
-        object_path=Path(result["object_path"]); assert result=={"digest":digest,"object_path":str(object_path)} and object_path.name==digest and object_path.read_bytes()==canonical_bytes(value=payload)+b"\n" and S.S_IMODE(object_path.stat().st_mode)==0o444 and any(f&os.O_TMPFILE==os.O_TMPFILE for _,f in opens) and [S.S_ISREG(x) for x in calls[:2]]==[True,True] and S.S_ISDIR(calls[2]) and not temps(object_path.parent)
+        finally: runtime.os.fsync,runtime.os.open,C.CDLL=oldf,oldo,oldl
+        object_path=Path(result["object_path"]); assert result=={"digest":digest,"object_path":str(object_path)} and object_path.name==digest and object_path.read_bytes()==canonical_bytes(value=payload)+b"\n" and S.S_IMODE(object_path.stat().st_mode)==0o444 and any(f&os.O_TMPFILE==os.O_TMPFILE for _,f in opens) and [(S.S_ISREG(x),S.S_IMODE(x)) for x in calls[:2]]==[(True,0o600),(True,0o444)] and S.S_ISDIR(calls[2]) and links==[(0x1000,-1),(0x400,0)] and not temps(object_path.parent)
         inode=object_path.stat().st_ino; calls=[]; runtime.os.fsync=lambda fd:(calls.append(os.fstat(fd).st_mode),oldf(fd))[1]
         try: assert result==runtime.publish_object(state_dir=str(state),artifact_store=str(store),object_kind="source_state",payload=payload,forbidden_roots=())
         finally: runtime.os.fsync=oldf
         assert object_path.stat().st_ino==inode and [S.S_ISREG(x) for x in calls]==[True,False] and S.S_ISDIR(calls[-1])
         stale=object_path.parent/".old.tmp.1.1"; stale.write_bytes(b"stale"); stale.chmod(0o600); before=tree(); bad(lambda:runtime.publish_object(state_dir=1,artifact_store=str(store),object_kind="source_state",payload={},forbidden_roots=[]),"ARGUMENT_ERROR"); bad(lambda:runtime.publish_object(state_dir=str(state),artifact_store=str(store),object_kind="source_state",payload={},forbidden_roots=()),"DESCRIPTOR_SCHEMA_INVALID"); bad(lambda:runtime.publish_object(state_dir=str(state),artifact_store=str(store),object_kind="trace",payload=payload,forbidden_roots=()),"ARGUMENT_ERROR"); assert tree()==before and outside.read_bytes()==b"fixed" and stale.read_bytes()==b"stale"
-        object_path.chmod(0o1444); before=tree(); bad(lambda:runtime.publish_object(state_dir=str(state),artifact_store=str(store),object_kind="source_state",payload=payload,forbidden_roots=()),"DIGEST_COLLISION"); object_path.chmod(0o644); object_path.write_bytes(b"collision"); object_path.chmod(0o444); bad(lambda:runtime.publish_object(state_dir=str(state),artifact_store=str(store),object_kind="source_state",payload=payload,forbidden_roots=()),"DIGEST_COLLISION"); assert tree()==before; object_path.unlink()
+        object_path.chmod(0o1444); before=tree(); bad(lambda:runtime.publish_object(state_dir=str(state),artifact_store=str(store),object_kind="source_state",payload=payload,forbidden_roots=()),"DIGEST_COLLISION"); object_path.chmod(0o644); object_path.write_bytes(collision:=b"collision"); object_path.chmod(0o444); bad(lambda:runtime.publish_object(state_dir=str(state),artifact_store=str(store),object_kind="source_state",payload=payload,forbidden_roots=()),"DIGEST_COLLISION"); assert tree()==before and object_path.read_bytes()==collision and S.S_IMODE(object_path.stat().st_mode)==0o444; object_path.unlink()
+        racing={**payload,"manifest_sha256":"4"*64}; racing_digest=domain_digest(domain_ascii=runtime._DOMAINS["source_state"],value=racing); racing_path=object_path.parent/racing_digest
+        for stage in ("classify","read","file","dir"):
+            phase=[]; before_fd=len(os.listdir("/proc/self/fd")); oldo,oldf,oldl=runtime.os.open,runtime.os.fsync,C.CDLL; loser=lambda *a:(os.link("/proc/self/fd/"+str(a[0]),a[3].decode(),dst_dir_fd=a[2],follow_symlinks=True),phase.append(True),C.set_errno(17),-1)[-1]
+            runtime.os.open=lambda p,f,m=0o777,dir_fd=None:(_ for _ in ()).throw(OSError(5,"recheck")) if phase and p==racing_digest and ((stage=="classify" and f&os.O_PATH) or (stage=="read" and not f&os.O_PATH)) else oldo(p,f,m,dir_fd=dir_fd); runtime.os.fsync=lambda x:(_ for _ in ()).throw(OSError(5,"recheck")) if phase and ((stage=="file" and S.S_ISREG(os.fstat(x).st_mode)) or (stage=="dir" and S.S_ISDIR(os.fstat(x).st_mode))) else oldf(x); C.CDLL=lambda *a,**k:type("L",(),{"linkat":staticmethod(loser)})()
+            try: bad(lambda:runtime.publish_object(state_dir=str(state),artifact_store=str(store),object_kind="source_state",payload=racing,forbidden_roots=()),"PUBLISH_PRECOMMIT_FAILED")
+            finally: runtime.os.open,runtime.os.fsync,C.CDLL=oldo,oldf,oldl
+            assert len(os.listdir("/proc/self/fd"))==before_fd and racing_path.read_bytes()==canonical_bytes(value=racing)+b"\n" and S.S_IMODE(racing_path.stat().st_mode)==0o444; racing_path.unlink()
         altered={**payload,"manifest_sha256":"1"*64}; absent=object_path.parent/domain_digest(domain_ascii=runtime._DOMAINS["source_state"],value=altered); os.mkfifo(absent,0o444); probe="import sys;sys.path.insert(0,"+repr(str(Path(__file__).parents[1]/".harness/closure/v1/lib"))+ ");from seed_contract_runtime import publish_object;publish_object(state_dir="+repr(str(state))+",artifact_store="+repr(str(store))+",object_kind='source_state',payload="+repr(altered)+",forbidden_roots=())"; run=subprocess.run([sys.executable,"-c",probe],capture_output=True,text=True,timeout=1); assert run.returncode==1 and run.stdout=="" and run.stderr.endswith("ContractError: DIGEST_COLLISION\n"); absent.unlink(); before=tree(); bad(lambda:runtime.publish_object(state_dir=str(state),artifact_store=str(store),object_kind="source_state",payload=altered,forbidden_roots=(),fault_point="OBJECT_LINK"),"PUBLISH_PRECOMMIT_FAILED"); assert not absent.exists() and tree()==before and temps(object_path.parent)==[stale]
         failed={**payload,"manifest_sha256":"3"*64}; failed_path=object_path.parent/domain_digest(domain_ascii=runtime._DOMAINS["source_state"],value=failed); oldc=runtime.os.fchmod; runtime.os.fchmod=lambda file,mode:(_ for _ in ()).throw(OSError()) if mode==0o444 else oldc(file,mode)
         try: bad(lambda:runtime.publish_object(state_dir=str(state),artifact_store=str(store),object_kind="source_state",payload=failed,forbidden_roots=()),"PUBLISH_PRECOMMIT_FAILED")
         finally: runtime.os.fchmod=oldc
         probe="import os,sys;sys.path.insert(0,"+repr(str(Path(__file__).parents[1]/".harness/closure/v1/lib"))+ ");import seed_contract_runtime as r;old=r.os.fchmod;r.os.fchmod=lambda f,m:os._exit(91) if m==0o444 else old(f,m);r.publish_object(state_dir="+repr(str(state))+",artifact_store="+repr(str(store))+",object_kind='source_state',payload="+repr(failed)+",forbidden_roots=())"; run=subprocess.run([sys.executable,"-c",probe],capture_output=True,text=True,timeout=1); assert run.returncode==91 and not failed_path.exists() and temps(object_path.parent)==[stale]
         orphan={**payload,"manifest_sha256":"2"*64}; orphan_path=object_path.parent/domain_digest(domain_ascii=runtime._DOMAINS["source_state"],value=orphan); bad(lambda:runtime.publish_object(state_dir=str(state),artifact_store=str(store),object_kind="source_state",payload=orphan,forbidden_roots=(),fault_point="OBJECT_DIR_FSYNC"),"PUBLISH_OBJECT_ORPHANED"); assert orphan_path.is_file() and orphan_path.stat().st_mode&0o777==0o444 and temps(object_path.parent)==[stale]
         calls=[]; runtime.os.fsync=lambda fd:(calls.append(os.fstat(fd).st_mode),oldf(fd))[1]
         try: runtime.publish_object(state_dir=str(state),artifact_store=str(store),object_kind="source_state",payload=orphan,forbidden_roots=())
         finally: runtime.os.fsync=oldf
         clean=root/"clean"; clean.mkdir()
```
