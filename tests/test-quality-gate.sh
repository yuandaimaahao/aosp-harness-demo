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
prepare_path() { local missing="$1" c; rm -rf -- "$case_bin"; mkdir "$case_bin"; for c in "${required[@]}"; do [[ "$c" == "$missing" ]] || { if [[ "$c" == bash ]]; then printf '#!%s\n[[ "$1" == -n ]] && printf "%%s\\0" "$2" >>"$SYNTAX_MARKER"\nexec "$HOST_BASH" "$@"\n' "$host_bash" >"$case_bin/bash"; chmod +x "$case_bin/bash"; elif [[ "$c" == sort ]]; then printf '#!%s\n[[ "${LC_ALL-}" == C ]] || exit 88\nexec %q "$@"\n' "$host_bash" "$(command -v sort)" >"$case_bin/sort"; chmod +x "$case_bin/sort"; else ln -s "$(command -v "$c")" "$case_bin/$c"; fi; }; done; }
run_error() { local label="$1" needle="$2" missing="$3" rc; shift 3; prepare_path "$missing"; : >"$syntax_marker"; : >"$test_marker"; set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" TEST_MARKER="$test_marker" "$host_bash" "$fixture/scripts/check.sh" "$@" >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e; [[ "$rc" -eq 2 ]] || fail "$label: expected rc=2"; grep -Fq "$needle" "$fixture/err" || fail "$label: expected $needle"; [[ ! -s "$syntax_marker" && ! -s "$test_marker" ]] || fail "$label: markers ran"; ! grep -Fq 'RESULT PASS  aosp-harness offline quality gate' "$fixture/out" || fail "$label: unexpected pass"; }
run_error 'cli no-argument' usage -
run_error 'cli unknown' usage - --unknown
run_error 'cli extra' usage - --offline extra
for missing in "${required[@]}"; do run_error "missing $missing" "missing required command: $missing" "$missing" --offline; done
prepare_path ''; : >"$syntax_marker"; set +e; HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" "$case_bin/bash" -n "$fixture/bad.sh" >/dev/null 2>&1; syntax_rc=$?; set -e
[[ "$syntax_rc" -eq 2 && -s "$syntax_marker" ]] || fail 'fake bash: expected syntax marker'
: >"$test_marker"; TEST_MARKER="$test_marker" "$host_bash" "$fixture/tests/test-marker.sh"
[[ -s "$test_marker" ]] || fail 'root test: expected marker'
[[ "$(QUALITY_GATE_NESTED=1 "$host_bash" "${BASH_SOURCE[0]}")" == 'RESULT PASS  offline quality gate child' ]] || fail 'nested: expected child pass'
rm -f "$fixture/bad.sh" "$fixture/tests/test-marker.sh"
prepare_path ''; set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" TEST_MARKER="$test_marker" "$host_bash" "$fixture/scripts/check.sh" --offline >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e
[[ "$rc" -eq 0 ]] || fail 'offline success: expected rc=0'
[[ "$(tail -n 1 "$fixture/out")" == 'RESULT PASS  aosp-harness offline quality gate' ]] || fail 'offline success: expected pass line'
rm -f "$fixture/bad.sh" "$fixture/tests/test-marker.sh"; body_log="$fixture/body"; root_log="$fixture/root"; outside="$(mktemp -d)"; trap 'rm -rf -- "$fixture" "$outside"' EXIT
lf_name=$'line\nentry'; printf '#!/bin/bash\n:\n' >"$fixture/entry"; printf '#!/usr/bin/env bash\n:\n' >"$fixture/space entry"; printf '#!/bin/bash\n:\n' >"$fixture/$lf_name"; printf 'if then\n' >"$fixture/bad.sh"
mkdir -p "$fixture/.spec"; printf 'if then\n' >"$fixture/.spec/ignored.sh"; printf 'if then\n' >"$fixture/.git/ignored.sh"; printf 'if then\n' >"$outside/poison.sh"; ln -s "$outside/poison.sh" "$fixture/link.sh"
printf '#!/usr/bin/env bash\n[[ "${QUALITY_GATE_NESTED-}" == 1 ]] || { printf body >>"$BODY_LOG"; exit 97; }; printf "RESULT PASS  offline quality gate child\\n"\n' >"$fixture/tests/test-quality-gate.sh"
for name in z a m; do printf '#!/usr/bin/env bash\nprintf %s >>"$ROOT_LOG"\n' "$name" >"$fixture/tests/test-$name.sh"; done
run_core() { set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" ROOT_LOG="$root_log" BODY_LOG="$body_log" "$host_bash" "$fixture/scripts/check.sh" --offline >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e; }
prepare_path ''; : >"$syntax_marker"; : >"$root_log"; run_core; [[ "$rc" -eq 1 && ! -s "$root_log" ]] || fail 'managed shell syntax was not checked'
printf '#!/bin/bash\n:\n' >"$fixture/bad.sh"; : >"$syntax_marker"; : >"$root_log"; : >"$body_log"; run_core
[[ "$rc" -eq 0 && "$(cat "$root_log")" == amz && ! -s "$body_log" ]] || fail 'managed shell ordering or nesting'
"$host_python" - "$syntax_marker" <<'PY'
from pathlib import Path
got=Path(__import__('sys').argv[1]).read_bytes().split(b'\0')
for path in (b'scripts/check.sh',b'entry',b'space entry',b'line\nentry',b'bad.sh'): assert got.count(path)==1, (path,got)
assert b'link.sh' not in got and not any(b'.git/' in x or b'.spec/' in x for x in got),got
PY
printf '#!/usr/bin/env bash\nprintf OUT\nprintf ERR >&2\nprintf m >>"$ROOT_LOG"\nexit 9\n' >"$fixture/tests/test-m.sh"; : >"$root_log"; run_core
[[ "$rc" -eq 1 && "$(cat "$root_log")" == am && "$(grep -Fxc OUT "$fixture/out")" == 1 && "$(grep -Fxc ERR "$fixture/err")" == 1 ]] || fail 'root test forwarding or short circuit'
poison_log="$fixture/poison"; for name in shellcheck shfmt gitleaks adb cvd curl wget ssh repo ninja claude codex; do printf '#!%s\nprintf %s >>%q\nexit 88\n' "$host_bash" "$name" "$poison_log" >"$case_bin/$name"; chmod +x "$case_bin/$name"; done
before="$("$host_git" hash-object claude-code/CURRENT_FEATURE codex/CURRENT_FEATURE common/CURRENT_FEATURE)"; PATH="$case_bin:$PATH" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" ROOT_LOG="$root_log" BODY_LOG="$body_log" GIT_ALLOW_PROTOCOL=file "$host_python" - "$repo_root" "$host_bash" <<'PY'
import os,subprocess,sys
r=subprocess.run([sys.argv[2],'./scripts/check.sh','--offline'],cwd=sys.argv[1],env=os.environ.copy(),text=True,capture_output=True,timeout=30); assert r.returncode==0 and r.stdout.count('RESULT PASS  offline quality gate child')==1,(r.stdout,r.stderr)
PY
[[ ! -s "$poison_log" && "$before" == "$("$host_git" hash-object claude-code/CURRENT_FEATURE codex/CURRENT_FEATURE common/CURRENT_FEATURE)" ]] || fail 'real offline boundary'
printf 'RESULT PASS  offline quality gate contract\n'
