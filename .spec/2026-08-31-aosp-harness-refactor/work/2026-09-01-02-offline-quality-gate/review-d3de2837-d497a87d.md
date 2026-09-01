# review 包 d3de2837..d497a87d

## commit 列表

```
d497a87 feat(quality): enforce incremental shell checks
```

## diff --stat

```
 scripts/check.sh                   | 13 +++++++++++++
 scripts/shell-quality-baseline.tsv | 30 ++++++++++++++++++++++++++++++
 tests/test-quality-gate.sh         | 33 ++++++++++++++++++++++++++++++++-
 3 files changed, 75 insertions(+), 1 deletion(-)
```

## diff

```diff
diff --git a/scripts/check.sh b/scripts/check.sh
index d3bbce8..4193de6 100755
--- a/scripts/check.sh
+++ b/scripts/check.sh
@@ -20,23 +20,36 @@ quality_list_shell_files() {
       [[ "$path" == *.sh || "$first" == '#!/usr/bin/env bash' || "$first" == '#!/bin/bash' ]] && printf '%s\0' "${path#./}"
     done | LC_ALL=C sort -z
 }
 quality_run_core() {
   local path; local -a shell_files=() root_tests=()
   while IFS= read -r -d '' path; do shell_files+=("$path"); done < <(quality_list_shell_files)
   for path in "${shell_files[@]}"; do bash -n "$path" || return 1; done
   while IFS= read -r -d '' path; do root_tests+=("${path#./}"); done < <(find ./tests -maxdepth 1 -type f -name 'test-*.sh' -print0 | LC_ALL=C sort -z)
   for path in "${root_tests[@]}"; do QUALITY_GATE_NESTED=1 bash "$path" || return 1; done
 }
+quality_run_static() {
+  local baseline_file="$repo_root/scripts/shell-quality-baseline.tsv" baseline_sha=62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f path blob; local -a shell_files=(); declare -A approved=()
+  [[ "$(sha256sum "$baseline_file" | awk '{print $1}')" == "$baseline_sha" ]] || quality_protocol_error 'baseline canonical digest mismatch'
+  LC_ALL=C awk -F '\t' 'NF != 2 || $1 == "" || $2 !~ /^[0-9a-f]{40}$/ || (NR > 1 && $1 <= previous) || paths[$1]++ || blobs[$2]++ {exit 1} {previous=$1} END {if (NR != 30) exit 1}' "$baseline_file" || quality_protocol_error 'baseline canonical format mismatch'
+  while IFS=$'\t' read -r path blob; do approved["$path"]="$blob"; done <"$baseline_file"
+  while IFS= read -r -d '' path; do shell_files+=("$path"); done < <(quality_list_shell_files)
+  for path in "${shell_files[@]}"; do
+    [[ "${approved[$path]-}" == "$(git hash-object "$path")" ]] && continue
+    shellcheck -x --severity=warning "$path" || return 1
+    shfmt -d -i 2 -ci -bn "$path" || return 1
+  done
+}
 if [[ "$mode" == --ci ]]; then
   for tool_spec in shellcheck:0.11.0 shfmt:3.14.0 gitleaks:8.30.1; do
     tool="${tool_spec%%:*}"; expected="${tool_spec#*:}"
     command -v "$tool" >/dev/null 2>&1 || quality_protocol_error "missing $tool $expected"
     case "$tool" in
       shellcheck) [[ "$(shellcheck --version | awk '/^version:/ {print $2}')" == 0.11.0 ]] || quality_protocol_error 'expected shellcheck 0.11.0' ;;
       shfmt) [[ "$(shfmt --version)" == v3.14.0 ]] || quality_protocol_error 'expected shfmt 3.14.0' ;;
       gitleaks) [[ "$(gitleaks version)" == 8.30.1 ]] || quality_protocol_error 'expected gitleaks 8.30.1' ;;
     esac
   done
 fi
 quality_run_core || exit 1
+[[ "$mode" != --ci ]] || quality_run_static || exit 1
 printf 'RESULT PASS  aosp-harness offline quality gate\n'
diff --git a/scripts/shell-quality-baseline.tsv b/scripts/shell-quality-baseline.tsv
new file mode 100644
index 0000000..21ab7a4
--- /dev/null
+++ b/scripts/shell-quality-baseline.tsv
@@ -0,0 +1,30 @@
+claude-code/features/.harness/bin/check-process-layer	25e0648a312551b864801b2bc2d952e5dabac7e5
+claude-code/features/.harness/bin/claude-feature	f1db0dca411ebd4db6fe9338d8dd450c098f8fd6
+claude-code/features/.harness/hooks/check-branch-drift.sh	d712e682f0e8fc308284ffcbc8e049332ce77083
+claude-code/features/.harness/hooks/feature-common.sh	6715482b008b4bb12a31ad4ca044461f2d9ad100
+claude-code/features/.harness/hooks/load-feature.sh	17bd013063f3423a70cf26391f2fa4dabebe58de
+claude-code/features/.harness/tests/test-harness.sh	b21a4e6c19cc0cc369fbc1dce8dfbde2c37499d8
+claude-code/features/.harness/tests/test-install-harness.sh	24163feeb19348a6aaa5760498c759d5dcc6b923
+claude-code/features/.harness/tests/test-link-migration-safety.sh	ccbc39e37c16e8ac9f231501f7033302a311140e
+claude-code/features/dev-sidebar/check-branch.sh	2a4c56138de258e5cec401a869a60cd06f75268b
+claude-code/features/dev-sidebar/verify-sidebar.sh	b34ff2a2b206152d4532fff89ae050ee16937e01
+claude-code/features/install-harness.sh	b36f8ebe51bc612a58b5f119c5ea9dbe5f1a678e
+claude-code/run-demo.sh	86e30c7bd086e3e022d73ecd9aebb8fa72cae091
+codex/.codex/bin/check-process-layer	818b0a37bc88a3e935f7e16800c59cddb4c062bc
+codex/.codex/bin/codex-feature	71cf9e7059742cfc9ebcd097c7f838fe60040e98
+codex/.codex/hooks/check-branch-drift.sh	e522ea8979bd8ebf33e0d756419fedc7a62b20d6
+codex/.codex/hooks/feature-common.sh	d2c0d005bb8cce9253ab4be9c83c000d5dd302f4
+codex/.codex/hooks/session-start.sh	21fba3e98ab5ce489067b01614c6c99ed1bea945
+codex/features/dev-sidebar/check-branch.sh	1938a83997447d2d148b634621b45289cd74b72b
+codex/features/dev-sidebar/verify-sidebar.sh	a39e421d0f93dcd3a71d250308f08aec5e1f292c
+codex/run-demo.sh	cff4dfa04fd1d807544570163199d47e334a9328
+codex/tests/test-harness.sh	41bb9b41640f3f50ac4c8e49793fd1fa9b31d5ae
+common/.claude/bin/claude-feature	b609204b09f0431ba176841f4daae7bd8865e301
+common/.codex/bin/codex-feature	57e178a3b740f229eba14627094159f071ec5ead
+common/.harness/bin/check-branches.sh	28d789693b6f20e85ad1c1ac9264a7f7cbae82f4
+common/.harness/bin/check-parity.sh	a2b8be34512ae9904327f6828bb2f6f37cf37747
+common/.harness/bin/resolve-feature.sh	f553c96f100c0e72f44b4af24c5c0360ba32af4f
+common/.harness/features/dev-sidebar/verify-sidebar.sh	1325e3f13e3b42c60b3d5685bf185d1766a29528
+common/run-demo.sh	39eaaae1e90cf2ca130d69da187118991d0cd111
+common/tests/test-harness.sh	873f5c6428790e0a9a8fc6a6c25bfdf5310d874b
+tests/test-device-safety.sh	98c1ecc5498339717361d19bf98b2974b4e81342
diff --git a/tests/test-quality-gate.sh b/tests/test-quality-gate.sh
index bb038cc..c17fee0 100755
--- a/tests/test-quality-gate.sh
+++ b/tests/test-quality-gate.sh
@@ -12,21 +12,21 @@ cp "$repo_root/scripts/check.sh" "$fixture/scripts/check.sh" 2>/dev/null || :
 printf 'if then\n' >"$fixture/bad.sh"; printf '#!/usr/bin/env bash\nprintf test >>"$TEST_MARKER"\n' >"$fixture/tests/test-marker.sh"
 required=(bash git python3 rg find sort awk sed grep sha256sum); case_bin="$fixture/bin"; syntax_marker="$fixture/syntax"; test_marker="$fixture/test"
 fail() { printf 'FAIL  %s\n' "$1"; exit 1; }
 prepare_path() { local missing="$1" c; rm -rf -- "$case_bin"; mkdir "$case_bin"; for c in "${required[@]}"; do [[ "$c" == "$missing" ]] || { if [[ "$c" == bash ]]; then printf '#!%s\n[[ "$1" == -n ]] && { printf "%%s\\0" "$2" >>"$SYNTAX_MARKER"; [[ -z "${EVENT_LOG-}" ]] || printf "syntax:%%s\\0" "$2" >>"$EVENT_LOG"; }\nexec "$HOST_BASH" "$@"\n' "$host_bash" >"$case_bin/bash"; chmod +x "$case_bin/bash"; elif [[ "$c" == sort ]]; then printf '#!%s\n[[ "${LC_ALL-}" == C ]] || exit 88\nexec %q "$@"\n' "$host_bash" "$(command -v sort)" >"$case_bin/sort"; chmod +x "$case_bin/sort"; else ln -s "$(command -v "$c")" "$case_bin/$c"; fi; }; done; }
 run_error() { local label="$1" needle="$2" missing="$3" rc; shift 3; prepare_path "$missing"; : >"$syntax_marker"; : >"$test_marker"; set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" TEST_MARKER="$test_marker" "$host_bash" "$fixture/scripts/check.sh" "$@" >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e; [[ "$rc" -eq 2 ]] || fail "$label: expected rc=2"; grep -Fq "$needle" "$fixture/err" || fail "$label: expected $needle"; [[ ! -s "$syntax_marker" && ! -s "$test_marker" ]] || fail "$label: markers ran"; ! grep -Fq 'RESULT PASS  aosp-harness offline quality gate' "$fixture/out" || fail "$label: unexpected pass"; }
 run_error 'cli no-argument' usage -
 run_error 'cli unknown' usage - --unknown
 run_error 'cli extra' usage - --offline extra
 for missing in "${required[@]}"; do run_error "missing $missing" "missing required command: $missing" "$missing" --offline; done
 tool_cases=(shellcheck:0.11.0 shfmt:3.14.0 gitleaks:8.30.1)
-fake_tool() { local tool="$1" response="$2"; printf '#!%s\ncase "$1" in --version|version) printf "%%s\\n" %q;; *) exit 90;; esac\n' "$host_bash" "$response" >"$case_bin/$tool"; chmod +x "$case_bin/$tool"; }
+fake_tool() { local tool="$1" response="$2"; printf '#!%s\ncase "$1" in --version|version) printf "%%s\\n" %q;; *) name="${0##*/}"; [[ -z "${STATIC_LOG_DIR-}" ]] || { printf "%%s\\0" "$@" >>"$STATIC_LOG_DIR/$name"; printf "\\0" >>"$STATIC_LOG_DIR/$name"; }; [[ "${FAIL_TOOL-}" != "$name" ]];; esac\n' "$host_bash" "$response" >"$case_bin/$tool"; chmod +x "$case_bin/$tool"; }
 install_ci_tools() { local spec tool version; for spec in "${tool_cases[@]}"; do tool="${spec%%:*}"; version="${spec#*:}"; case "$tool" in shellcheck) fake_tool "$tool" "version: $version";; shfmt) fake_tool "$tool" "v$version";; gitleaks) fake_tool "$tool" "$version";; esac; done; }
 run_ci_error() { local label="$1" tool="$2" version="$3" state="$4" rc; prepare_path ''; install_ci_tools; [[ "$state" == missing ]] && rm "$case_bin/$tool" || fake_tool "$tool" wrong; : >"$syntax_marker"; : >"$test_marker"; set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" TEST_MARKER="$test_marker" "$host_bash" "$fixture/scripts/check.sh" --ci >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e; [[ "$rc" -eq 2 && ! -s "$syntax_marker" && ! -s "$test_marker" ]] || fail "ci $tool $state: expected rc=2 before core"; grep -Fq "$tool" "$fixture/err" && grep -Fq "$version" "$fixture/err" || fail "ci $tool $state: expected version"; ! grep -Fq 'RESULT PASS  aosp-harness offline quality gate' "$fixture/out" || fail "ci $tool $state: unexpected pass"; }
 for spec in "${tool_cases[@]}"; do tool="${spec%%:*}"; version="${spec#*:}"; run_ci_error "$tool" "$tool" "$version" missing; run_ci_error "$tool" "$tool" "$version" wrong; done
 prepare_path ''; install_ci_tools; : >"$syntax_marker"; : >"$test_marker"; set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" TEST_MARKER="$test_marker" "$host_bash" "$fixture/scripts/check.sh" --ci >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e; [[ "$rc" -eq 1 && -s "$syntax_marker" && ! -s "$test_marker" ]] || fail 'ci correct tools: expected core syntax failure'; ! grep -Fq 'RESULT PASS  aosp-harness offline quality gate' "$fixture/out" || fail 'ci correct tools: unexpected pass'
 prepare_path ''; : >"$syntax_marker"; set +e; HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" "$case_bin/bash" -n "$fixture/bad.sh" >/dev/null 2>&1; syntax_rc=$?; set -e
 [[ "$syntax_rc" -eq 2 && -s "$syntax_marker" ]] || fail 'fake bash: expected syntax marker'
 : >"$test_marker"; TEST_MARKER="$test_marker" "$host_bash" "$fixture/tests/test-marker.sh"
 [[ -s "$test_marker" ]] || fail 'root test: expected marker'
 [[ "$(QUALITY_GATE_NESTED=1 "$host_bash" "${BASH_SOURCE[0]}")" == 'RESULT PASS  offline quality gate child' ]] || fail 'nested: expected child pass'
 rm -f "$fixture/bad.sh" "$fixture/tests/test-marker.sh"
@@ -50,17 +50,48 @@ for path in (b'scripts/check.sh',b'entry',b'space entry',b'line\nentry',b'bad.sh
 assert b'link.sh' not in got and not any(b'.git/' in x or b'.spec/' in x for x in got),got
 first=next(i for i,event in enumerate(events) if event.startswith(b'root:'))
 assert events[:first]==[b'syntax:'+path for path in got[:-1]],events
 PY
 then fail 'syntax events were not ordered'; fi
 cwd_marker="$outside/cwd"; mkdir -p "$unrelated/tests"; printf '#!/usr/bin/env bash\nprintf poison >>%q\n' "$cwd_marker" >"$unrelated/tests/test-poison.sh"; : >"$root_log"; : >"$event_log"
 (cd "$unrelated" && PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" ROOT_LOG="$root_log" BODY_LOG="$body_log" EVENT_LOG="$event_log" "$host_bash" "$fixture/scripts/check.sh" --offline >"$fixture/cwd-out" 2>"$fixture/cwd-err")
 [[ ! -s "$cwd_marker" && "$(cat "$root_log")" == amz && "$(grep -Fxc 'RESULT PASS  offline quality gate child' "$fixture/cwd-out")" == 1 ]] || fail 'unrelated cwd escaped fixture root'
 printf '#!/usr/bin/env bash\nprintf OUT\nprintf ERR >&2\nprintf m >>"$ROOT_LOG"\nexit 9\n' >"$fixture/tests/test-m.sh"; : >"$root_log"; run_core
 [[ "$rc" -eq 1 && "$(cat "$root_log")" == am && "$(grep -Fxc OUT "$fixture/out")" == 1 && "$(grep -Fxc ERR "$fixture/err")" == 1 ]] || fail 'root test forwarding or short circuit'
+baseline="$repo_root/scripts/shell-quality-baseline.tsv"; baseline_sha=62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f
+[[ -f "$baseline" && "$(wc -l <"$baseline")" -eq 30 && "$(sha256sum "$baseline" | awk '{print $1}')" == "$baseline_sha" ]] || fail 'baseline canonical digest mismatch'
+"$host_python" - "$baseline" <<'PY' || fail 'baseline canonical format mismatch'
+import re,sys
+rows=[line.split('\t') for line in open(sys.argv[1],encoding='utf-8').read().splitlines()]
+assert all(len(row)==2 and row[0] and re.fullmatch(r'[0-9a-f]{40}',row[1]) for row in rows)
+assert [row[0] for row in rows]==sorted(row[0] for row in rows) and len({row[0] for row in rows})==30 and len({row[1] for row in rows})==30
+PY
+static_fixture="$(mktemp -d)"; static_logs="$static_fixture/logs"; mkdir -p "$static_fixture/scripts" "$static_logs"; git init -q "$static_fixture"; trap 'rm -rf -- "$fixture" "$outside" "$unrelated" "$static_fixture"' EXIT
+cp "$repo_root/scripts/check.sh" "$baseline" "$static_fixture/scripts/"; approved=claude-code/features/.harness/bin/check-process-layer; mkdir -p "$static_fixture/${approved%/*}"; cp "$repo_root/$approved" "$static_fixture/$approved"; printf '#!/bin/bash\n:\n' >"$static_fixture/new.sh"
+run_static() { : >"$static_logs/shellcheck"; : >"$static_logs/shfmt"; : >"$static_logs/gitleaks"; set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$static_fixture/syntax" STATIC_LOG_DIR="$static_logs" FAIL_TOOL="${1-}" "$host_bash" "$static_fixture/scripts/check.sh" --ci >"$static_fixture/out" 2>"$static_fixture/err"; static_rc=$?; set -e; }
+prepare_path ''; install_ci_tools; run_static
+[[ "$static_rc" -eq 0 && ! -s "$static_logs/gitleaks" ]] || fail 'baseline static success contract'
+"$host_python" - "$static_logs" "$approved" <<'PY' || fail 'baseline static argv contract'
+from pathlib import Path
+import sys
+root=Path(sys.argv[1]); approved=sys.argv[2].encode(); expected=[b'new.sh',b'scripts/check.sh']
+for tool,prefix in ((b'shellcheck',[b'-x',b'--severity=warning']),(b'shfmt',[b'-d',b'-i',b'2',b'-ci',b'-bn'])):
+ records=[part.split(b'\0') for part in (root/tool.decode()).read_bytes().split(b'\0\0') if part]
+ assert records==[prefix+[path] for path in expected] and all(approved not in record for record in records),records
+PY
+printf '\n# changed\n' >>"$static_fixture/$approved"; run_static
+"$host_python" - "$static_logs" "$approved" <<'PY' || fail 'changed baseline pair was exempted'
+from pathlib import Path
+import sys
+root=Path(sys.argv[1]); expected=[sys.argv[2].encode(),b'new.sh',b'scripts/check.sh']
+for tool,prefix in (('shellcheck',[b'-x',b'--severity=warning']),('shfmt',[b'-d',b'-i',b'2',b'-ci',b'-bn'])): assert [part.split(b'\0') for part in (root/tool).read_bytes().split(b'\0\0') if part]==[prefix+[path] for path in expected]
+PY
+for fail_tool in shellcheck shfmt; do run_static "$fail_tool"; [[ "$static_rc" -eq 1 ]] || fail "$fail_tool finding: expected rc=1"; done
+mutations=(append-current wrong-digest duplicate unsorted malformed non-anchor)
+for mutation in "${mutations[@]}"; do cp "$baseline" "$static_fixture/scripts/shell-quality-baseline.tsv"; case "$mutation" in append-current|non-anchor) printf 'new.sh\t%s\n' "$(git -C "$static_fixture" hash-object new.sh)" >>"$static_fixture/scripts/shell-quality-baseline.tsv";; wrong-digest) sed -i '1s/[0-9a-f]$/0/' "$static_fixture/scripts/shell-quality-baseline.tsv";; duplicate) head -n 1 "$baseline" >>"$static_fixture/scripts/shell-quality-baseline.tsv";; unsorted) sed -i '1{h;d};2{G}' "$static_fixture/scripts/shell-quality-baseline.tsv";; malformed) printf 'bad\n' >>"$static_fixture/scripts/shell-quality-baseline.tsv";; esac; run_static; [[ "$static_rc" -eq 2 && ! -s "$static_logs/shellcheck" && ! -s "$static_logs/shfmt" && ! -s "$static_logs/gitleaks" ]] || fail "baseline $mutation: expected protocol error before tools"; done
 poison_log="$fixture/poison"; for name in shellcheck shfmt gitleaks adb cvd curl wget ssh repo ninja claude codex; do printf '#!%s\nprintf %s >>%q\nexit 88\n' "$host_bash" "$name" "$poison_log" >"$case_bin/$name"; chmod +x "$case_bin/$name"; done
 before="$("$host_git" hash-object claude-code/CURRENT_FEATURE codex/CURRENT_FEATURE common/CURRENT_FEATURE)"; PATH="$case_bin:$PATH" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" ROOT_LOG="$root_log" BODY_LOG="$body_log" GIT_ALLOW_PROTOCOL=file "$host_python" - "$repo_root" "$host_bash" <<'PY'
 import os,subprocess,sys
 r=subprocess.run([sys.argv[2],'./scripts/check.sh','--offline'],cwd=sys.argv[1],env=os.environ.copy(),text=True,capture_output=True,timeout=30); assert r.returncode==0 and r.stdout.count('RESULT PASS  offline quality gate child')==1,(r.stdout,r.stderr)
 PY
 [[ ! -s "$poison_log" && "$before" == "$("$host_git" hash-object claude-code/CURRENT_FEATURE codex/CURRENT_FEATURE common/CURRENT_FEATURE)" ]] || fail 'real offline boundary'
 printf 'RESULT PASS  offline quality gate contract\n'
```
