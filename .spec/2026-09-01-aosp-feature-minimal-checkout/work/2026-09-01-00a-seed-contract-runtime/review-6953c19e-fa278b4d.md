# review 包 6953c19e..fa278b4d

## commit 列表

```
fa278b4 feat(harness): add seed verification cli
```

## diff --stat

```
 common/.harness/bin/feature-closure                | 12 ++++++++++
 common/.harness/closure/v1/commands.d/verify-seed  | 28 ++++++++++++++++++++++
 .../v1/runtime/seed-contract-runtime.version       |  1 +
 common/tests/test-seed-contract-runtime.sh         |  9 +++++++
 common/tests/test_seed_contract_runtime.py         | 28 +++++++++++++++++++++-
 5 files changed, 77 insertions(+), 1 deletion(-)
```

## diff

```diff
diff --git a/common/.harness/bin/feature-closure b/common/.harness/bin/feature-closure
new file mode 100755
index 0000000..0906b9b
--- /dev/null
+++ b/common/.harness/bin/feature-closure
@@ -0,0 +1,12 @@
+#!/usr/bin/env bash
+set -euo pipefail
+fail() { printf 'CONTRACT %s\n' "$1" >&2; exit 30; }
+(($#)) || fail ARGUMENT_ERROR
+command=$1
+[[ $command =~ ^[a-z][a-z0-9-]{0,31}$ ]] || fail INVALID_COMMAND
+self=$(realpath -- "$0") || fail COMMAND_UNAVAILABLE
+parent=$(dirname -- "$self")
+target=$(dirname -- "$parent")/closure/v1/commands.d/$command
+[[ -f $target && ! -L $target && -x $target ]] || fail COMMAND_UNAVAILABLE
+shift
+exec "$target" "$@"
diff --git a/common/.harness/closure/v1/commands.d/verify-seed b/common/.harness/closure/v1/commands.d/verify-seed
new file mode 100755
index 0000000..da0ea2c
--- /dev/null
+++ b/common/.harness/closure/v1/commands.d/verify-seed
@@ -0,0 +1,28 @@
+#!/usr/bin/env python3
+import os, stat, sys
+from pathlib import Path
+def fail(code): print("CONTRACT " + code, file=sys.stderr); raise SystemExit(30)
+base = Path(__file__).resolve().parents[1]
+try:
+    marker, module = base / "runtime/seed-contract-runtime.version", base / "lib/seed_contract_runtime.py"
+    for path in (marker, module):
+        info = os.lstat(path)
+        if not stat.S_ISREG(info.st_mode) or stat.S_ISLNK(info.st_mode): raise OSError()
+    if marker.read_bytes() != b"seed-contract-runtime/v1\n": raise OSError()
+    sys.path.insert(0, str(base / "lib"))
+    from seed_contract_runtime import (ContractError, RUNTIME_ABI, load_artifact, canonical_bytes, domain_digest, validate_state_paths, resolve_ref, publish_object, publish)
+    if RUNTIME_ABI != "seed-contract-runtime/v1": raise OSError()
+except BaseException: fail("RUNTIME_UNAVAILABLE")
+try:
+    if os.environ.get("AOSP_HARNESS_TEST_UNEXPECTED") == "call-shape-type-error": canonical_bytes({})
+    args = sys.argv[1:]
+    if len(args) == 1 and not args[0].startswith("--"):
+        value = load_artifact(path=args[0], expected_kind="seed"); canonical_bytes(value=value); suffix = ""
+    elif len(args) in (4, 5) and args[0] == "--ref" and args[2] == "--artifact-store" and not args[1].startswith("--") and not args[3].startswith("--") and (len(args) == 4 or args[4] == "--require-public-real"):
+        store, ref, public = args[3], args[1], len(args) == 5
+        value = resolve_ref(state_dir=str(Path(store).parent.parent), ref=ref, artifact_store=store, forbidden_roots=(str(base.parents[3]),), require_public_real=public)
+        value["kind"] == "seed" or (_ for _ in ()).throw(ContractError("REF_CORRUPT")); suffix = " public_aosp17_cuttlefish" if public else ""
+    else: raise ContractError("ARGUMENT_ERROR")
+    print("SEED ABI PASS" + suffix)
+except ContractError as error: fail(error.code)
+except BaseException: fail("RUNTIME_INTERNAL")
diff --git a/common/.harness/closure/v1/runtime/seed-contract-runtime.version b/common/.harness/closure/v1/runtime/seed-contract-runtime.version
new file mode 100644
index 0000000..1bcddce
--- /dev/null
+++ b/common/.harness/closure/v1/runtime/seed-contract-runtime.version
@@ -0,0 +1 @@
+seed-contract-runtime/v1
diff --git a/common/tests/test-seed-contract-runtime.sh b/common/tests/test-seed-contract-runtime.sh
new file mode 100755
index 0000000..61af6d5
--- /dev/null
+++ b/common/tests/test-seed-contract-runtime.sh
@@ -0,0 +1,9 @@
+#!/usr/bin/env bash
+set -euo pipefail
+[[ $# -eq 2 && $1 == --case && $2 == cli ]] || { printf 'RESULT FAIL seed-contract-runtime\n' >&2; exit 1; }
+root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
+if output=$(cd "$root" && python3 common/tests/test_seed_contract_runtime.py cli 2>&1) && [[ $output == 'PASS cli' ]]; then
+  printf 'RESULT PASS seed-contract-runtime\n'
+else
+  printf '%s\n' "$output" >&2; exit 1
+fi
diff --git a/common/tests/test_seed_contract_runtime.py b/common/tests/test_seed_contract_runtime.py
index 00638c1..0b33461 100644
--- a/common/tests/test_seed_contract_runtime.py
+++ b/common/tests/test_seed_contract_runtime.py
@@ -171,14 +171,40 @@ def ref_publish():
         put=lambda v:(lambda q:((Path(store)/"sha256"/q).write_bytes(canonical_bytes(value=v)+b"\n"),(Path(store)/"sha256"/q).chmod(0o444),q)[2])(domain_digest(domain_ascii=runtime._DOMAINS[v["kind"]],value=v)); sd,td,jd=put(state0),put(trace),put(journal); seed=json.loads((Path(__file__).parent/"fixtures/aosp17-services/seed.golden.json").read_text()); seed["manifest"]["projects"][0]["source_state_digest"]=domain_digest(domain_ascii=runtime._DOMAINS["project_source_state"],value=state0["projects"][0]); seed["source_state"].update(before_digest=sd,after_digest=sd); seed["guard"].update(trace_digest=td,command_journal_digest=jd); seed["seed_content_digest"]=domain_digest(domain_ascii=runtime._DOMAINS["seed_content"],value=runtime._seed_parts(seed)[1]); seed["seed_identity_digest"]=domain_digest(domain_ascii=runtime._DOMAINS["seed_identity"],value=runtime._seed_parts(seed)[2])
         seedref=state/"refs/seed"; seeded=runtime.publish(state_dir=str(state),out_ref=str(seedref),artifact_store=str(store),object_kind="seed",payload=seed,ref_kind="env_pass",semantic_exit=0,forbidden_roots=()); assert seeded["semantic_exit"]==0 and runtime._decode(seedref.read_bytes())["kind"]=="env_pass" and runtime.resolve_ref(state_dir=str(state),ref=str(seedref),artifact_store=str(store),forbidden_roots=())==seed; stale=ref.parent/".pass.tmp.999999999.0123456789abcdef"; other=ref.parent/".other.tmp.999999999.0123456789abcdef"; stale.write_bytes(other.write_bytes(b"x") and b"x"); stale.chmod(0o600); other.chmod(0o600); call(p); assert not stale.exists() and other.exists(); coll=make(6); cpath=Path(store)/"sha256"/domain_digest(domain_ascii=runtime._DOMAINS["terminal_report"],value=coll); cstale=ref.parent/".pass.tmp.999999998.0123456789abcdef"; cpath.write_bytes(b"bad"); cpath.chmod(0o444); cstale.write_bytes(b"stale"); cstale.chmod(0o600); snap=(cpath.read_bytes(),cstale.read_bytes(),ref.read_bytes(),sentinel.read_bytes()); bad(lambda:call(coll),"DIGEST_COLLISION"); assert snap==(cpath.read_bytes(),cstale.read_bytes(),ref.read_bytes(),sentinel.read_bytes()); cpath.unlink(); cstale.unlink()
         missing=make(5); missing["completed_observation_digests"]["trace"]="f"*64; ref.write_bytes(b"bad"); snapshot=(ref.read_bytes(),sentinel.read_bytes()); bad(lambda:call(missing),"REF_CORRUPT"); bad(lambda:runtime.publish(state_dir=str(state),out_ref=str(ref),artifact_store=str(store),object_kind="wrong",payload={},ref_kind="wrong",semantic_exit=20,forbidden_roots=()),"ARGUMENT_ERROR"); bad(lambda:call({}),"DESCRIPTOR_SCHEMA_INVALID"); bad(lambda:call({"schema_version":1,"kind":"source_state"}),"ARGUMENT_ERROR"); bad(lambda:call(seed),"ARGUMENT_ERROR"); assert (ref.read_bytes(),sentinel.read_bytes())==snapshot; ref.write_bytes(before)
         def one(_):
             try: return call(p)
             except runtime.ContractError as error: return error.code
         with F.ThreadPoolExecutor(max_workers=8) as pool: outcomes=list(pool.map(one,range(8)))
         assert all(x==result or x=="REF_BUSY" for x in outcomes) and runtime.resolve_ref(state_dir=str(state),ref=str(ref),artifact_store=str(store),forbidden_roots=())==p and not [x for x in root.rglob("*") if x.name.startswith(".pass.tmp.")] and sentinel.read_bytes()==b"fixed"; beforefd=len(os.listdir("/proc/self/fd")); oldc=runtime.os.close; hit=[]; runtime.os.close=lambda fd:(oldc(fd),(_ for _ in ()).throw(OSError(5,"close")))[1] if not hit and __import__("stat").S_ISDIR(os.fstat(fd).st_mode) and os.fstat(fd).st_ino==ref.parent.stat().st_ino and not runtime.fcntl.fcntl(fd,runtime.fcntl.F_GETFL)&os.O_PATH and not hit.append(1) else oldc(fd); call(p); runtime.os.close=oldc; assert hit and len(os.listdir("/proc/self/fd"))==beforefd; beforefd=len(os.listdir("/proc/self/fd")); oldc=runtime.os.close; hit=[]; runtime.os.close=lambda fd:(oldc(fd),(_ for _ in ()).throw(OSError(5,"close")))[1] if not hit and __import__("stat").S_ISDIR(os.fstat(fd).st_mode) and os.fstat(fd).st_ino==obj.parent.stat().st_ino and not runtime.fcntl.fcntl(fd,runtime.fcntl.F_GETFL)&os.O_PATH and not hit.append(1) else oldc(fd); call(p); runtime.os.close=oldc; assert hit and len(os.listdir("/proc/self/fd"))==beforefd; stale=ref.parent/".pass.tmp.999999997.0123456789abcdef"; stale.write_bytes(b"x"); stale.chmod(0o600); beforefd=len(os.listdir("/proc/self/fd")); oldf=runtime.os.fstat; hit=[]; runtime.os.fstat=lambda fd:(_ for _ in ()).throw(OSError(5,"fstat")) if not hit and runtime.fcntl.fcntl(fd,runtime.fcntl.F_GETFL)&os.O_PATH and oldf(fd).st_ino==stale.stat().st_ino and not hit.append(1) else oldf(fd); call(p); runtime.os.fstat=oldf; assert hit and len(os.listdir("/proc/self/fd"))==beforefd; stale.unlink()
         stale=ref.parent/".pass.tmp.999999996.0123456789abcdef"; stale.write_bytes(b"x"); stale.chmod(0o600); beforefd=len(os.listdir("/proc/self/fd")); oldc=runtime._close; reused=[]; runtime._close=lambda fd:(oldc(fd),reused.append((fd,os.open("/dev/null",os.O_RDONLY))))[0] if not reused and os.fstat(fd).st_ino==stale.stat().st_ino else oldc(fd)
         call(p); runtime._close=oldc; assert reused and reused[0][0]==reused[0][1] and os.fstat(reused[0][1]) and not stale.exists() and not [x for x in root.rglob("*") if x.name.startswith(".pass.tmp.")]; os.close(reused[0][1]); assert len(os.listdir("/proc/self/fd"))==beforefd
+def cli():
+    root=Path(__file__).parents[2]; direct=root/"common/.harness/closure/v1/commands.d/verify-seed"; dispatch=root/"common/.harness/bin/feature-closure"; marker=root/"common/.harness/closure/v1/runtime/seed-contract-runtime.version"; golden=root/"common/tests/fixtures/aosp17-services/seed.golden.json"; run=lambda *a,env=None:subprocess.run(a,capture_output=True,text=True,env=env,timeout=5)
+    def exact(r,c,o,e): assert (r.returncode,r.stdout,r.stderr)==(c,o,e)
+    def check(cmd,code): r=run(*cmd); exact(r,30,"",f"CONTRACT {code}\n")
+    ok=run(str(direct),str(golden)); exact(ok,0,"SEED ABI PASS\n",""); through=run(str(dispatch),"verify-seed",str(golden)); exact(through,0,ok.stdout,ok.stderr)
+    for cmd in ((str(dispatch),"BAD!","--bad"),(str(direct),),(str(direct),str(golden),"--ref","x"),(str(direct),"--artifact-store","x","--ref","y")): check(cmd,"INVALID_COMMAND" if cmd[0]==str(dispatch) else "ARGUMENT_ERROR")
+    with tempfile.TemporaryDirectory() as directory:
+        state=Path(directory); ref=state/"refs/missing"; store=state/"artifacts/v1"; a=("--ref",str(ref),"--artifact-store",str(store)); one=run(str(direct),*a); two=run(str(dispatch),"verify-seed",*a); exact(one,30,"","CONTRACT ARTIFACT_MISSING\n"); exact(two,one.returncode,one.stdout,one.stderr)
+    with tempfile.TemporaryDirectory() as directory:
+        runtime=__import__("seed_contract_runtime"); state=Path(directory); store=state/"artifacts/v1"; h="0"*64; source={"schema_version":1,"kind":"source_state","manifest_sha256":h,"projects":[{"path":"a","head":"0"*40,"status_sha256":h,"entries":[]}]}; trace={"schema_version":1,"kind":"trace","records":[{"sequence":1,"process_ordinal":0,"syscall":"x","result":0,"errno":None,"exec_argv_b64":None,"paths":[],"address_family":None,"classification":"other"}],"counts":dict(other=1,external_network=0,source_mutation=0,sync_download=0,config_query=0,module_build=0,package=0)}
+        journal={"schema_version":1,"kind":"command_journal","records":[{"stage":x,"argv_b64":[],"cwd_b64":"","exit_code":0,"trace_first_sequence":1,"trace_last_sequence":1} for x in ("manifest_before","source_state_before","namespace_probe","envsetup_lunch","manifest_after","source_state_after")]}; put=lambda p:runtime.publish_object(state_dir=str(state),artifact_store=str(store),object_kind=p["kind"],payload=p,forbidden_roots=())["digest"]; sd,td,jd=put(source),put(trace),put(journal)
+        seed=json.loads(golden.read_text()); seed["manifest"]["projects"][0]["source_state_digest"]=runtime.domain_digest(domain_ascii=runtime._DOMAINS["project_source_state"],value=source["projects"][0]); seed["source_state"].update(before_digest=sd,after_digest=sd); seed["guard"].update(trace_digest=td,command_journal_digest=jd); seed["seed_content_digest"]=runtime.domain_digest(domain_ascii=runtime._DOMAINS["seed_content"],value=runtime._seed_parts(seed)[1]); seed["seed_identity_digest"]=runtime.domain_digest(domain_ascii=runtime._DOMAINS["seed_identity"],value=runtime._seed_parts(seed)[2]); ref=state/"refs/seed"; runtime.publish(state_dir=str(state),out_ref=str(ref),artifact_store=str(store),object_kind="seed",payload=seed,ref_kind="env_pass",semantic_exit=0,forbidden_roots=())
+        a=("--ref",str(ref),"--artifact-store",str(store)); one=run(str(direct),*a); two=run(str(dispatch),"verify-seed",*a); exact(one,0,"SEED ABI PASS\n",""); exact(two,one.returncode,one.stdout,one.stderr); check((str(direct),*a,"--require-public-real"),"PUBLIC_SCOPE_REQUIRED"); check((str(dispatch),"verify-seed",*a,"--require-public-real"),"PUBLIC_SCOPE_REQUIRED")
+    backup=direct.with_name("verify-seed.backup"); direct.rename(backup)
+    try: check((str(dispatch),"verify-seed","--bad"),"COMMAND_UNAVAILABLE")
+    finally: backup.rename(direct)
+    direct.rename(backup); direct.symlink_to(root/"common/.harness/bin/check-parity.sh")
+    try: check((str(dispatch),"verify-seed","--bad"),"COMMAND_UNAVAILABLE")
+    finally: direct.unlink(); backup.rename(direct)
+    mode=direct.stat().st_mode; direct.chmod(0o644)
+    try: check((str(dispatch),"verify-seed","--bad"),"COMMAND_UNAVAILABLE")
+    finally: direct.chmod(mode)
+    saved=marker.read_bytes(); marker.unlink()
+    try: check((str(direct),"--bad"),"RUNTIME_UNAVAILABLE")
+    finally: marker.write_bytes(saved)
+    seam=run(str(direct),str(golden),env={**os.environ,"AOSP_HARNESS_TEST_UNEXPECTED":"call-shape-type-error"}); exact(seam,30,"","CONTRACT RUNTIME_INTERNAL\n"); assert "Traceback" not in seam.stderr
 if __name__ == "__main__":
-    cases = {"canonical-core": core, "concurrent-core": concurrent, "evidence-schema": evidence,"seed-schema":seed,"terminal-golden":terminal,"state-paths":state_paths,"store-object":store_object,"ref-resolve":ref_resolve,"ref-publish":ref_publish}
+    cases = {"canonical-core": core, "concurrent-core": concurrent, "evidence-schema": evidence,"seed-schema":seed,"terminal-golden":terminal,"state-paths":state_paths,"store-object":store_object,"ref-resolve":ref_resolve,"ref-publish":ref_publish,"cli":cli}
     try: [(cases[case](), print("PASS " + case)) for case in sys.argv[1:]]
     except (IndexError, KeyError): raise SystemExit("usage: canonical-core|concurrent-core") from None
```
