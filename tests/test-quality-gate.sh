#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)"; host_bash="$(command -v bash)"; host_python="$(command -v python3)"; host_git="$(command -v git)"
[[ "$host_bash" == /* && -x "$host_bash" ]] || exit 99
if [[ "${QUALITY_GATE_NESTED-}" == 1 ]]; then
  printf 'RESULT PASS  offline quality gate child\n'
  exit 0
fi
fixture="$(mktemp -d)"; trap 'rm -rf -- "$fixture"' EXIT
git init -q "$fixture"; mkdir -p "$fixture/scripts" "$fixture/tests"
cp "$repo_root/scripts/check.sh" "$fixture/scripts/check.sh" 2>/dev/null || :
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
fake_tool() { local tool="$1" response="$2"; printf '#!%s\ncase "$1" in --version|version) printf "%%s\\n" %q;; *) name="${0##*/}"; [[ -z "${STATIC_LOG_DIR-}" ]] || { printf "%%s\\0" "$@" >>"$STATIC_LOG_DIR/$name"; printf "\\0" >>"$STATIC_LOG_DIR/$name"; }; [[ "${FAIL_TOOL-}" != "$name" ]];; esac\n' "$host_bash" "$response" >"$case_bin/$tool"; chmod +x "$case_bin/$tool"; }
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
prepare_path ''; set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" TEST_MARKER="$test_marker" "$host_bash" "$fixture/scripts/check.sh" --offline >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e
[[ "$rc" -eq 0 ]] || fail 'offline success: expected rc=0'
[[ "$(tail -n 1 "$fixture/out")" == 'RESULT PASS  aosp-harness offline quality gate' ]] || fail 'offline success: expected pass line'
rm -f "$fixture/bad.sh" "$fixture/tests/test-marker.sh"; body_log="$fixture/body"; root_log="$fixture/root"; event_log="$fixture/events"; outside="$(mktemp -d)"; unrelated="$(mktemp -d)"; trap 'rm -rf -- "$fixture" "$outside" "$unrelated"' EXIT
lf_name=$'line\nentry'; printf '#!/bin/bash\n:\n' >"$fixture/entry"; printf '#!/usr/bin/env bash\n:\n' >"$fixture/space entry"; printf '#!/bin/bash\n:\n' >"$fixture/$lf_name"; printf 'if then\n' >"$fixture/bad.sh"
mkdir -p "$fixture/.spec"; printf 'if then\n' >"$fixture/.spec/ignored.sh"; printf 'if then\n' >"$fixture/.git/ignored.sh"; printf 'if then\n' >"$outside/poison.sh"; ln -s "$outside/poison.sh" "$fixture/link.sh"
printf '#!/usr/bin/env bash\n[[ "${QUALITY_GATE_NESTED-}" == 1 ]] || { printf body >>"$BODY_LOG"; exit 97; }; printf "root:test-quality-gate.sh\\0" >>"$EVENT_LOG"; printf "RESULT PASS  offline quality gate child\\n"\n' >"$fixture/tests/test-quality-gate.sh"
for name in z a m; do printf '#!/usr/bin/env bash\nprintf %s >>"$ROOT_LOG"\nprintf "root:test-%s.sh\\0" >>"$EVENT_LOG"\n' "$name" "$name" >"$fixture/tests/test-$name.sh"; done
run_core() { set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" ROOT_LOG="$root_log" BODY_LOG="$body_log" EVENT_LOG="$event_log" "$host_bash" "$fixture/scripts/check.sh" --offline >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e; }
prepare_path ''; : >"$syntax_marker"; : >"$root_log"; run_core; [[ "$rc" -eq 1 && ! -s "$root_log" ]] || fail 'managed shell syntax was not checked'
printf '#!/bin/bash\n:\n' >"$fixture/bad.sh"; : >"$syntax_marker"; : >"$root_log"; : >"$body_log"; : >"$event_log"; run_core
[[ "$rc" -eq 0 && "$(cat "$root_log")" == amz && ! -s "$body_log" ]] || fail 'managed shell ordering or nesting'
if ! "$host_python" - "$syntax_marker" "$event_log" <<'PY'
from pathlib import Path
import sys
got=Path(sys.argv[1]).read_bytes().split(b'\0'); events=Path(sys.argv[2]).read_bytes().split(b'\0')[:-1]
for path in (b'scripts/check.sh',b'entry',b'space entry',b'line\nentry',b'bad.sh'): assert got.count(path)==1, (path,got)
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
baseline="$repo_root/scripts/shell-quality-baseline.tsv"; baseline_sha=62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f
[[ -f "$baseline" && "$(wc -l <"$baseline")" -eq 30 && "$(sha256sum "$baseline" | awk '{print $1}')" == "$baseline_sha" ]] || fail 'baseline canonical digest mismatch'
"$host_python" - "$baseline" <<'PY' || fail 'baseline canonical format mismatch'
import re,sys
rows=[line.split('\t') for line in open(sys.argv[1],encoding='utf-8').read().splitlines()]
assert all(len(row)==2 and row[0] and re.fullmatch(r'[0-9a-f]{40}',row[1]) for row in rows)
assert [row[0] for row in rows]==sorted(row[0] for row in rows) and len({row[0] for row in rows})==30 and len({row[1] for row in rows})==30
PY
static_fixture="$(mktemp -d)"; static_logs="$static_fixture/logs"; mkdir -p "$static_fixture/scripts" "$static_logs"; git init -q "$static_fixture"; trap 'rm -rf -- "$fixture" "$outside" "$unrelated" "$static_fixture"' EXIT
cp "$repo_root/scripts/check.sh" "$baseline" "$static_fixture/scripts/"; approved=claude-code/features/.harness/bin/check-process-layer; mkdir -p "$static_fixture/${approved%/*}"; cp "$repo_root/$approved" "$static_fixture/$approved"; printf '#!/bin/bash\n:\n' >"$static_fixture/new.sh"
run_static() { : >"$static_logs/shellcheck"; : >"$static_logs/shfmt"; : >"$static_logs/gitleaks"; set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$static_fixture/syntax" STATIC_LOG_DIR="$static_logs" FAIL_TOOL="${1-}" "$host_bash" "$static_fixture/scripts/check.sh" --ci >"$static_fixture/out" 2>"$static_fixture/err"; static_rc=$?; set -e; }
prepare_path ''; install_ci_tools; run_static
[[ "$static_rc" -eq 0 && ! -s "$static_logs/gitleaks" ]] || fail 'baseline static success contract'
"$host_python" - "$static_logs" "$approved" <<'PY' || fail 'baseline static argv contract'
from pathlib import Path
import sys
root=Path(sys.argv[1]); approved=sys.argv[2].encode(); expected=[b'new.sh',b'scripts/check.sh']
for tool,prefix in ((b'shellcheck',[b'-x',b'--severity=warning']),(b'shfmt',[b'-d',b'-i',b'2',b'-ci',b'-bn'])):
 records=[part.split(b'\0') for part in (root/tool.decode()).read_bytes().split(b'\0\0') if part]
 assert records==[prefix+[path] for path in expected] and all(approved not in record for record in records),records
PY
printf '\n# changed\n' >>"$static_fixture/$approved"; run_static
"$host_python" - "$static_logs" "$approved" <<'PY' || fail 'changed baseline pair was exempted'
from pathlib import Path
import sys
root=Path(sys.argv[1]); expected=[sys.argv[2].encode(),b'new.sh',b'scripts/check.sh']
for tool,prefix in (('shellcheck',[b'-x',b'--severity=warning']),('shfmt',[b'-d',b'-i',b'2',b'-ci',b'-bn'])): assert [part.split(b'\0') for part in (root/tool).read_bytes().split(b'\0\0') if part]==[prefix+[path] for path in expected]
PY
for fail_tool in shellcheck shfmt; do run_static "$fail_tool"; [[ "$static_rc" -eq 1 ]] || fail "$fail_tool finding: expected rc=1"; done
mutations=(append-current wrong-digest duplicate unsorted malformed non-anchor)
for mutation in "${mutations[@]}"; do cp "$baseline" "$static_fixture/scripts/shell-quality-baseline.tsv"; case "$mutation" in append-current|non-anchor) printf 'new.sh\t%s\n' "$(git -C "$static_fixture" hash-object new.sh)" >>"$static_fixture/scripts/shell-quality-baseline.tsv";; wrong-digest) sed -i '1s/[0-9a-f]$/0/' "$static_fixture/scripts/shell-quality-baseline.tsv";; duplicate) head -n 1 "$baseline" >>"$static_fixture/scripts/shell-quality-baseline.tsv";; unsorted) sed -i '1{h;d};2{G}' "$static_fixture/scripts/shell-quality-baseline.tsv";; malformed) printf 'bad\n' >>"$static_fixture/scripts/shell-quality-baseline.tsv";; esac; run_static; [[ "$static_rc" -eq 2 && ! -s "$static_logs/shellcheck" && ! -s "$static_logs/shfmt" && ! -s "$static_logs/gitleaks" ]] || fail "baseline $mutation: expected protocol error before tools"; done
poison_log="$fixture/poison"; for name in shellcheck shfmt gitleaks adb cvd curl wget ssh repo ninja claude codex; do printf '#!%s\nprintf %s >>%q\nexit 88\n' "$host_bash" "$name" "$poison_log" >"$case_bin/$name"; chmod +x "$case_bin/$name"; done
before="$("$host_git" hash-object claude-code/CURRENT_FEATURE codex/CURRENT_FEATURE common/CURRENT_FEATURE)"; PATH="$case_bin:$PATH" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" ROOT_LOG="$root_log" BODY_LOG="$body_log" GIT_ALLOW_PROTOCOL=file "$host_python" - "$repo_root" "$host_bash" <<'PY'
import os,subprocess,sys
r=subprocess.run([sys.argv[2],'./scripts/check.sh','--offline'],cwd=sys.argv[1],env=os.environ.copy(),text=True,capture_output=True,timeout=30); assert r.returncode==0 and r.stdout.count('RESULT PASS  offline quality gate child')==1,(r.stdout,r.stderr)
PY
[[ ! -s "$poison_log" && "$before" == "$("$host_git" hash-object claude-code/CURRENT_FEATURE codex/CURRENT_FEATURE common/CURRENT_FEATURE)" ]] || fail 'real offline boundary'
printf 'RESULT PASS  offline quality gate contract\n'
