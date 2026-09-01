# review 包 d497a87d..9be78e07

## commit 列表

```
9be78e0 test(quality): strengthen incremental shell contract
```

## diff --stat

```
 tests/test-quality-gate.sh | 50 ++++++++++++++++++++++++----------------------
 1 file changed, 26 insertions(+), 24 deletions(-)
```

## diff

```diff
diff --git a/tests/test-quality-gate.sh b/tests/test-quality-gate.sh
index c17fee0..dd96b84 100755
--- a/tests/test-quality-gate.sh
+++ b/tests/test-quality-gate.sh
@@ -52,46 +52,48 @@ first=next(i for i,event in enumerate(events) if event.startswith(b'root:'))
 assert events[:first]==[b'syntax:'+path for path in got[:-1]],events
 PY
 then fail 'syntax events were not ordered'; fi
 cwd_marker="$outside/cwd"; mkdir -p "$unrelated/tests"; printf '#!/usr/bin/env bash\nprintf poison >>%q\n' "$cwd_marker" >"$unrelated/tests/test-poison.sh"; : >"$root_log"; : >"$event_log"
 (cd "$unrelated" && PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" ROOT_LOG="$root_log" BODY_LOG="$body_log" EVENT_LOG="$event_log" "$host_bash" "$fixture/scripts/check.sh" --offline >"$fixture/cwd-out" 2>"$fixture/cwd-err")
 [[ ! -s "$cwd_marker" && "$(cat "$root_log")" == amz && "$(grep -Fxc 'RESULT PASS  offline quality gate child' "$fixture/cwd-out")" == 1 ]] || fail 'unrelated cwd escaped fixture root'
 printf '#!/usr/bin/env bash\nprintf OUT\nprintf ERR >&2\nprintf m >>"$ROOT_LOG"\nexit 9\n' >"$fixture/tests/test-m.sh"; : >"$root_log"; run_core
 [[ "$rc" -eq 1 && "$(cat "$root_log")" == am && "$(grep -Fxc OUT "$fixture/out")" == 1 && "$(grep -Fxc ERR "$fixture/err")" == 1 ]] || fail 'root test forwarding or short circuit'
 baseline="$repo_root/scripts/shell-quality-baseline.tsv"; baseline_sha=62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f
 [[ -f "$baseline" && "$(wc -l <"$baseline")" -eq 30 && "$(sha256sum "$baseline" | awk '{print $1}')" == "$baseline_sha" ]] || fail 'baseline canonical digest mismatch'
-"$host_python" - "$baseline" <<'PY' || fail 'baseline canonical format mismatch'
-import re,sys
-rows=[line.split('\t') for line in open(sys.argv[1],encoding='utf-8').read().splitlines()]
-assert all(len(row)==2 and row[0] and re.fullmatch(r'[0-9a-f]{40}',row[1]) for row in rows)
-assert [row[0] for row in rows]==sorted(row[0] for row in rows) and len({row[0] for row in rows})==30 and len({row[1] for row in rows})==30
-PY
+baseline_valid() { LC_ALL=C awk -F '\t' 'NF != 2 || $1 == "" || $2 !~ /^[0-9a-f]{40}$/ || (NR > 1 && $1 <= previous) || paths[$1]++ || blobs[$2]++ {exit 1} {previous=$1} END {if (NR != 30) exit 1}' "$1"; }
 static_fixture="$(mktemp -d)"; static_logs="$static_fixture/logs"; mkdir -p "$static_fixture/scripts" "$static_logs"; git init -q "$static_fixture"; trap 'rm -rf -- "$fixture" "$outside" "$unrelated" "$static_fixture"' EXIT
-cp "$repo_root/scripts/check.sh" "$baseline" "$static_fixture/scripts/"; approved=claude-code/features/.harness/bin/check-process-layer; mkdir -p "$static_fixture/${approved%/*}"; cp "$repo_root/$approved" "$static_fixture/$approved"; printf '#!/bin/bash\n:\n' >"$static_fixture/new.sh"
+cp "$repo_root/scripts/check.sh" "$baseline" "$static_fixture/scripts/"; approved=claude-code/features/.harness/bin/check-process-layer; mkdir -p "$static_fixture/${approved%/*}"; cp "$repo_root/$approved" "$static_fixture/$approved"; printf '#!/bin/bash\n:\n' >"$static_fixture/new.sh"; odd=$'candidate\n with space.sh'; printf '#!/bin/bash\n:\n' >"$static_fixture/$odd"
 run_static() { : >"$static_logs/shellcheck"; : >"$static_logs/shfmt"; : >"$static_logs/gitleaks"; set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$static_fixture/syntax" STATIC_LOG_DIR="$static_logs" FAIL_TOOL="${1-}" "$host_bash" "$static_fixture/scripts/check.sh" --ci >"$static_fixture/out" 2>"$static_fixture/err"; static_rc=$?; set -e; }
-prepare_path ''; install_ci_tools; run_static
-[[ "$static_rc" -eq 0 && ! -s "$static_logs/gitleaks" ]] || fail 'baseline static success contract'
-"$host_python" - "$static_logs" "$approved" <<'PY' || fail 'baseline static argv contract'
-from pathlib import Path
-import sys
-root=Path(sys.argv[1]); approved=sys.argv[2].encode(); expected=[b'new.sh',b'scripts/check.sh']
-for tool,prefix in ((b'shellcheck',[b'-x',b'--severity=warning']),(b'shfmt',[b'-d',b'-i',b'2',b'-ci',b'-bn'])):
- records=[part.split(b'\0') for part in (root/tool.decode()).read_bytes().split(b'\0\0') if part]
- assert records==[prefix+[path] for path in expected] and all(approved not in record for record in records),records
+assert_calls() { "$host_python" - "$static_logs" "$1" "$approved" "$odd" <<'PY'
+from pathlib import Path; import sys; root,mode,approved,odd=Path(sys.argv[1]),sys.argv[2],sys.argv[3].encode(),sys.argv[4].encode()
+candidates=[odd,b'new.sh',b'scripts/check.sh']; changed=[odd,approved]+candidates[1:]
+wanted={'base':(candidates,candidates),'changed':(changed,changed),'shellcheck':([odd],[]),'shfmt':([odd],[odd]),'protocol':([],[])}
+specs=(('shellcheck',[b'-x',b'--severity=warning'],wanted[mode][0]),('shfmt',[b'-d',b'-i',b'2',b'-ci',b'-bn'],wanted[mode][1]),('gitleaks',[],[]))
+for tool,prefix,paths in specs:
+ records=[part.split(b'\0') for part in (root/tool).read_bytes().split(b'\0\0') if part]; assert records==[prefix+[path] for path in paths],(tool,records)
 PY
+}
+prepare_path ''; install_ci_tools; run_static; assert_calls base || fail 'baseline static success: argv bytes'
 printf '\n# changed\n' >>"$static_fixture/$approved"; run_static
-"$host_python" - "$static_logs" "$approved" <<'PY' || fail 'changed baseline pair was exempted'
-from pathlib import Path
-import sys
-root=Path(sys.argv[1]); expected=[sys.argv[2].encode(),b'new.sh',b'scripts/check.sh']
-for tool,prefix in (('shellcheck',[b'-x',b'--severity=warning']),('shfmt',[b'-d',b'-i',b'2',b'-ci',b'-bn'])): assert [part.split(b'\0') for part in (root/tool).read_bytes().split(b'\0\0') if part]==[prefix+[path] for path in expected]
-PY
-for fail_tool in shellcheck shfmt; do run_static "$fail_tool"; [[ "$static_rc" -eq 1 ]] || fail "$fail_tool finding: expected rc=1"; done
+assert_calls changed || fail 'changed baseline pair: argv bytes'
+for fail_tool in shellcheck shfmt; do run_static "$fail_tool"
+  [[ "$static_rc" -eq 1 ]] || fail "$fail_tool finding: expected rc=1"
+  assert_calls "$fail_tool" || fail "$fail_tool finding: calls after failure"
+  [[ ! -s "$static_logs/gitleaks" ]] || fail "$fail_tool finding: gitleaks called"
+  ! grep -Fq 'RESULT PASS  aosp-harness offline quality gate' "$static_fixture/out" || fail "$fail_tool finding: unexpected pass"
+done
 mutations=(append-current wrong-digest duplicate unsorted malformed non-anchor)
-for mutation in "${mutations[@]}"; do cp "$baseline" "$static_fixture/scripts/shell-quality-baseline.tsv"; case "$mutation" in append-current|non-anchor) printf 'new.sh\t%s\n' "$(git -C "$static_fixture" hash-object new.sh)" >>"$static_fixture/scripts/shell-quality-baseline.tsv";; wrong-digest) sed -i '1s/[0-9a-f]$/0/' "$static_fixture/scripts/shell-quality-baseline.tsv";; duplicate) head -n 1 "$baseline" >>"$static_fixture/scripts/shell-quality-baseline.tsv";; unsorted) sed -i '1{h;d};2{G}' "$static_fixture/scripts/shell-quality-baseline.tsv";; malformed) printf 'bad\n' >>"$static_fixture/scripts/shell-quality-baseline.tsv";; esac; run_static; [[ "$static_rc" -eq 2 && ! -s "$static_logs/shellcheck" && ! -s "$static_logs/shfmt" && ! -s "$static_logs/gitleaks" ]] || fail "baseline $mutation: expected protocol error before tools"; done
+for mutation in "${mutations[@]}"; do cp "$baseline" "$static_fixture/scripts/shell-quality-baseline.tsv"; case "$mutation" in
+  append-current) printf 'new.sh\t%s\n' "$(git -C "$static_fixture" hash-object new.sh)" >>"$static_fixture/scripts/shell-quality-baseline.tsv";;
+  non-anchor) sed -i "1s/[0-9a-f]\{40\}$/$(git -C "$static_fixture" hash-object new.sh)/" "$static_fixture/scripts/shell-quality-baseline.tsv";;
+  wrong-digest) sed -i '1s/[0-9a-f]$/0/' "$static_fixture/scripts/shell-quality-baseline.tsv";; duplicate) head -n 1 "$baseline" >>"$static_fixture/scripts/shell-quality-baseline.tsv";;
+  unsorted) sed -i '1{h;d};2{G}' "$static_fixture/scripts/shell-quality-baseline.tsv";; malformed) printf 'bad\n' >>"$static_fixture/scripts/shell-quality-baseline.tsv";; esac
+  case "$mutation" in append-current) [[ "$(wc -l <"$static_fixture/scripts/shell-quality-baseline.tsv")" -eq 31 ]] || fail 'baseline append-current: expected row 31';; non-anchor) baseline_valid "$static_fixture/scripts/shell-quality-baseline.tsv" || fail 'baseline non-anchor: fixture format';; esac
+  run_static; [[ "$static_rc" -eq 2 ]] || fail "baseline $mutation: expected rc=2"
+  assert_calls protocol || fail "baseline $mutation: tools called"; done
 poison_log="$fixture/poison"; for name in shellcheck shfmt gitleaks adb cvd curl wget ssh repo ninja claude codex; do printf '#!%s\nprintf %s >>%q\nexit 88\n' "$host_bash" "$name" "$poison_log" >"$case_bin/$name"; chmod +x "$case_bin/$name"; done
 before="$("$host_git" hash-object claude-code/CURRENT_FEATURE codex/CURRENT_FEATURE common/CURRENT_FEATURE)"; PATH="$case_bin:$PATH" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" ROOT_LOG="$root_log" BODY_LOG="$body_log" GIT_ALLOW_PROTOCOL=file "$host_python" - "$repo_root" "$host_bash" <<'PY'
 import os,subprocess,sys
 r=subprocess.run([sys.argv[2],'./scripts/check.sh','--offline'],cwd=sys.argv[1],env=os.environ.copy(),text=True,capture_output=True,timeout=30); assert r.returncode==0 and r.stdout.count('RESULT PASS  offline quality gate child')==1,(r.stdout,r.stderr)
 PY
 [[ ! -s "$poison_log" && "$before" == "$("$host_git" hash-object claude-code/CURRENT_FEATURE codex/CURRENT_FEATURE common/CURRENT_FEATURE)" ]] || fail 'real offline boundary'
 printf 'RESULT PASS  offline quality gate contract\n'
```
