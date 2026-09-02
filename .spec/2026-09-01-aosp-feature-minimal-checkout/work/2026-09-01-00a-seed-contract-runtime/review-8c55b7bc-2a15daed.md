# review 包 8c55b7bc..2a15daed

## commit 列表

```
2a15dae test(harness): add seed contract invariant routes
```

## diff --stat

```
 common/tests/test-seed-contract-runtime.sh | 33 +++++++++++++++++++++++++-----
 common/tests/test_seed_contract_runtime.py | 11 +++++++++-
 2 files changed, 38 insertions(+), 6 deletions(-)
```

## diff

```diff
diff --git a/common/tests/test-seed-contract-runtime.sh b/common/tests/test-seed-contract-runtime.sh
index 61af6d5..68717e1 100755
--- a/common/tests/test-seed-contract-runtime.sh
+++ b/common/tests/test-seed-contract-runtime.sh
@@ -1,9 +1,32 @@
 #!/usr/bin/env bash
 set -euo pipefail
-[[ $# -eq 2 && $1 == --case && $2 == cli ]] || { printf 'RESULT FAIL seed-contract-runtime\n' >&2; exit 1; }
 root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
-if output=$(cd "$root" && python3 common/tests/test_seed_contract_runtime.py cli 2>&1) && [[ $output == 'PASS cli' ]]; then
-  printf 'RESULT PASS seed-contract-runtime\n'
-else
-  printf '%s\n' "$output" >&2; exit 1
+fail(){ printf '%s\n' "$1" >&2; exit 1; }
+case_name=all; ledger=
+if [[ $# -gt 0 ]]; then
+  [[ $# -ge 2 && $1 == --case ]] || fail 'RESULT FAIL seed-contract-runtime'
+  case_name=$2; shift 2
 fi
+if [[ $case_name == rollback ]]; then
+  [[ $# == 2 && $1 == --ledger && -f $2 ]] || fail 'ROLLBACK ERROR active delivery candidate unavailable'
+  ledger=$2
+  candidate=$(cd "$root" && python3 common/tests/test_seed_contract_runtime.py ledger-candidate --ledger "$ledger" 2>&1) || fail 'ROLLBACK ERROR active delivery candidate unavailable'
+  [[ $candidate == 'PASS ledger-candidate active '* ]] || fail 'ROLLBACK ERROR active delivery candidate unavailable'
+  sha=${candidate##* }; parents=$(git -C "$root" rev-list --parents -n 1 "$sha" 2>/dev/null) || fail 'RESULT FAIL seed-contract-runtime'
+  [[ $(wc -w <<<"$parents") == 3 ]] || fail 'RESULT FAIL seed-contract-runtime'
+  tmp=$(mktemp -d); cleanup(){ git -C "$root" worktree remove --force "$tmp" >/dev/null 2>&1 && [[ ! -e $tmp ]] && ! git -C "$root" worktree list --porcelain | grep -Fqx "worktree $tmp"; }
+  trap 'cleanup || exit 1' EXIT
+  git -C "$root" worktree add --detach "$tmp" "$sha" >/dev/null 2>&1 || fail 'RESULT FAIL seed-contract-runtime'
+  fixture=$tmp/common/.harness/closure/v1/commands.d/recovery-fixture
+  cp "$tmp/common/.harness/closure/v1/commands.d/verify-seed" "$fixture" && chmod 0755 "$fixture" && git -C "$tmp" add -- "$fixture" && git -C "$tmp" -c user.name=rollback -c user.email=rollback@invalid commit -m 'test: add recovery fixture' >/dev/null 2>&1 && git -C "$tmp" -c user.name=rollback -c user.email=rollback@invalid revert -m 1 --no-edit "$sha" >/dev/null 2>&1 || fail 'RESULT FAIL seed-contract-runtime'
+  set +e; out=$($fixture 2>"$tmp/err"); rc=$?; set -e
+  [[ $rc == 30 && -z $out && $(<"$tmp/err") == 'CONTRACT RUNTIME_UNAVAILABLE' && -x $fixture && ! -e $tmp/common/.harness/bin/feature-closure && ! -e $tmp/common/.harness/closure/v1/runtime/seed-contract-runtime.version && ! -e $tmp/common/.harness/closure/v1/lib/seed_contract_runtime.py && ! -e $tmp/common/.harness/closure/v1/commands.d/verify-seed ]] || fail 'RESULT FAIL seed-contract-runtime'
+  h=$(cd "$tmp" && bash common/tests/test-harness.sh 2>"$tmp/herr") && p=$(cd "$tmp" && bash common/.harness/bin/check-parity.sh 2>"$tmp/perr") && s=$(cd "$tmp" && bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo 2>"$tmp/serr") || fail 'RESULT FAIL seed-contract-runtime'
+  [[ ! -s $tmp/herr && ! -s $tmp/perr && ! -s $tmp/serr && ${h##*$'\n'} == 'RESULT PASS  shared Harness regression suite' && $p == 'PARITY PASS  Claude/Codex 共享同一公共契约' && ${s##*$'\n'} == 'RESULT PASS' ]] || fail 'RESULT FAIL seed-contract-runtime'
+  trap - EXIT; cleanup || fail 'RESULT FAIL seed-contract-runtime'; printf 'RESULT PASS seed-contract-runtime\n'; exit 0
+fi
+[[ $# == 0 ]] || fail 'RESULT FAIL seed-contract-runtime'
+declare -A routes=([all]='canonical-core evidence-schema seed-schema terminal-golden state-paths store-object ref-resolve ref-publish cli' [cli]=cli [digest-immutability]='store-object ref-publish' [path-confinement]=state-paths [failure-ref-rules]=ref-publish [public-real-gate]=ref-resolve)
+tests=${routes[$case_name]-}; [[ -n $tests ]] || fail 'RESULT FAIL seed-contract-runtime'
+output=$(cd "$root" && python3 common/tests/test_seed_contract_runtime.py $tests 2>&1) || fail "$output"
+printf 'RESULT PASS seed-contract-runtime\n'
diff --git a/common/tests/test_seed_contract_runtime.py b/common/tests/test_seed_contract_runtime.py
index ed3d087..ed43ed6 100644
--- a/common/tests/test_seed_contract_runtime.py
+++ b/common/tests/test_seed_contract_runtime.py
@@ -199,14 +199,23 @@ def cli():
     finally: direct.unlink(); backup.rename(direct)
     mode=direct.stat().st_mode; direct.chmod(0o644)
     try: check((str(dispatch),"verify-seed","--bad"),"COMMAND_UNAVAILABLE")
     finally: direct.chmod(mode)
     saved=marker.read_bytes(); marker.unlink()
     try: check((str(direct),"--bad"),"RUNTIME_UNAVAILABLE")
     finally: marker.write_bytes(saved); extra=direct.parent/"nonregular"; extra.mkdir(); check((str(dispatch),"nonregular","--bad"),"COMMAND_UNAVAILABLE"); extra.rmdir()
     seam=run(str(direct),str(golden),env={**os.environ,"AOSP_HARNESS_TEST_UNEXPECTED":"call-shape-type-error"}); exact(seam,30,"","CONTRACT RUNTIME_INTERNAL\n"); assert "Traceback" not in seam.stderr
     q=tempfile.TemporaryDirectory(); poison=Path(q.name); (poison/"sitecustomize.py").write_text("import sys,types;m=types.ModuleType('seed_contract_runtime');m.RUNTIME_ABI='seed-contract-runtime/v1';m.ContractError=Exception;m.load_artifact=lambda **x:{};m.canonical_bytes=lambda **x:b'';m.domain_digest=lambda **x:'';m.validate_state_paths=lambda **x:{};m.resolve_ref=lambda **x:{};m.publish_object=lambda **x:{};m.publish=lambda **x:{};sys.modules['seed_contract_runtime']=m"); r=run(str(direct),"/definitely/not/a/seed.json",env={**os.environ,"PYTHONPATH":str(poison)}); exact(r,30,"","CONTRACT DESCRIPTOR_NOT_FOUND\n"); q.cleanup()
     code="from pathlib import Path\nimport os,subprocess\nd=Path(%r);m=Path(%r);u=Path(%r)\ndef x(p,f):\n b=p.read_bytes();z=p.with_name(p.name+'.save');p.rename(z)\n try:\n  f(p);r=subprocess.run([str(d),'--bad'],capture_output=True,text=True);assert(r.returncode,r.stdout,r.stderr)==(30,'','CONTRACT RUNTIME_UNAVAILABLE\\n')\n finally:\n  (p.rmdir() if p.is_dir() else p.unlink()) if p.exists() or p.is_symlink() else None;z.rename(p)\nfor p,f in ((m,lambda p:p.write_bytes(b'bad')),(m,lambda p:p.symlink_to('/dev/null')),(m,lambda p:p.mkdir()),(u,lambda p:None),(u,lambda p:p.symlink_to('/dev/null')),(u,lambda p:p.mkdir()),(u,lambda p:p.write_text('x=')),(u,lambda p:p.write_text(\"RUNTIME_ABI='seed-contract-runtime/v1'\"))):x(p,f)"%(str(direct),str(marker),str(root/"common/.harness/closure/v1/lib/seed_contract_runtime.py")); r=run(sys.executable,"-c",code); exact(r,0,"","")
+def ledger_candidate():
+    import re
+    active=final=None
+    for line in Path(sys.argv[3]).read_text().splitlines():
+        if "delivery-candidate" in line:
+            match=re.search(r"delivery-candidate sha=([0-9a-f]{40}) status=(active|superseded|accepted)$",line); assert match
+            sha,status=match.groups(); assert (status=="active" and active is final is None) or (status in ("superseded","accepted") and active==sha)
+            active=sha if status=="active" else None; final=(sha,status) if status=="accepted" else final
+    assert sys.argv[2:3]==["--ledger"] and len(sys.argv)==4 and (active or final); print("PASS ledger-candidate",*((final[1],final[0]) if final else ("active",active)))
 if __name__ == "__main__":
     cases = {"canonical-core": core, "concurrent-core": concurrent, "evidence-schema": evidence,"seed-schema":seed,"terminal-golden":terminal,"state-paths":state_paths,"store-object":store_object,"ref-resolve":ref_resolve,"ref-publish":ref_publish,"cli":cli}
-    try: [(cases[case](), print("PASS " + case)) for case in sys.argv[1:]]
+    try: ledger_candidate() if sys.argv[1:2]==["ledger-candidate"] else [(cases[case](), print("PASS " + case)) for case in sys.argv[1:]]
     except (IndexError, KeyError): raise SystemExit("usage: canonical-core|concurrent-core") from None
```
