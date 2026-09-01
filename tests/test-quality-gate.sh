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
fake_tool() { local tool="$1" response="$2"; printf '#!%s\ncase "$1" in --version|version) printf "%%s\\n" %q;; *) name="${0##*/}"; if [[ "$name" == gitleaks ]]; then printf "GITLEAKS_CONFIG=%%s\\0GITLEAKS_CONFIG_TOML=%%s\\0" "${GITLEAKS_CONFIG-unset}" "${GITLEAKS_CONFIG_TOML-unset}" >>"$STATIC_LOG_DIR/$name"; printf "%%s\\0" "$@" >>"$STATIC_LOG_DIR/$name"; printf "\\0" >>"$STATIC_LOG_DIR/$name"; target="${@: -1}"; state="$STATIC_LOG_DIR/gitleaks-state"; if [[ ! -e "$state" ]]; then [[ "$target/" != "$STATIC_REPO/"* && -f "$target/canary.txt" && "$(<"$target/canary.txt")" == "aws_access_key_id = ${CANARY_PREFIX-AKIA}${CANARY_SUFFIX-ABCDEFGHIJKLMNOP}" ]] || exit 93; printf "%%s" "$target" >"$state"; exit "${CANARY_RC-1}"; fi; previous="$(<"$state")"; [[ "$target" == "$STATIC_REPO" && ! -e "$previous" ]] || exit 94; exit "${WORKTREE_RC-0}"; fi; [[ -z "${STATIC_LOG_DIR-}" ]] || { printf "%%s\\0" "$@" >>"$STATIC_LOG_DIR/$name"; printf "\\0" >>"$STATIC_LOG_DIR/$name"; }; [[ "${FAIL_TOOL-}" != "$name" ]];; esac\n' "$host_bash" "$response" >"$case_bin/$tool"; chmod +x "$case_bin/$tool"; }
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
baseline_valid() { LC_ALL=C awk -F '\t' 'NF != 2 || $1 == "" || $2 !~ /^[0-9a-f]{40}$/ || (NR > 1 && $1 <= previous) || paths[$1]++ || blobs[$2]++ {exit 1} {previous=$1} END {if (NR != 30) exit 1}' "$1"; }
static_fixture="$(mktemp -d)"; static_logs="$static_fixture/logs"; mkdir -p "$static_fixture/scripts" "$static_logs"; git init -q "$static_fixture"; trap 'rm -rf -- "$fixture" "$outside" "$unrelated" "$static_fixture"' EXIT
config="$repo_root/.gitleaks.toml"; config_sha=27630a96d6c55755cc37620f3933d5cab94b1eb78a726a32e11212972525d76e; [[ "$(sha256sum "$config" | awk '{print $1}')" == "$config_sha" ]] || fail 'gitleaks config digest'
cp "$repo_root/scripts/check.sh" "$baseline" "$static_fixture/scripts/"; approved=claude-code/features/.harness/bin/check-process-layer; mkdir -p "$static_fixture/${approved%/*}"; cp "$repo_root/$approved" "$static_fixture/$approved"; printf '#!/bin/bash\n:\n' >"$static_fixture/new.sh"; odd=$'candidate\n with space.sh'; printf '#!/bin/bash\n:\n' >"$static_fixture/$odd"
cp "$config" "$static_fixture/"
run_static() { : >"$static_logs/shellcheck"; : >"$static_logs/shfmt"; : >"$static_logs/gitleaks"; rm -f "$static_logs/gitleaks-state"; set +e; PATH="$case_bin:$(dirname "$(command -v mktemp)")" HOST_BASH="$host_bash" SYNTAX_MARKER="$static_fixture/syntax" STATIC_LOG_DIR="$static_logs" STATIC_REPO="$static_fixture" FAIL_TOOL="${1-}" CANARY_RC="${2-1}" WORKTREE_RC="${3-0}" TMPDIR="${4-/tmp}" GITLEAKS_CONFIG=poison-primary GITLEAKS_CONFIG_TOML=poison-toml "$host_bash" "$static_fixture/scripts/check.sh" --ci >"$static_fixture/out" 2>"$static_fixture/err"; static_rc=$?; set -e; }
assert_calls() { "$host_python" - "$static_logs" "$1" "$approved" "$odd" <<'PY'
from pathlib import Path; import sys; root,mode,approved,odd=Path(sys.argv[1]),sys.argv[2],sys.argv[3].encode(),sys.argv[4].encode()
candidates=[odd,b'new.sh',b'scripts/check.sh']; changed=[odd,approved]+candidates[1:]
wanted={'base':(candidates,candidates),'changed':(changed,changed),'shellcheck':([odd],[]),'shfmt':([odd],[odd]),'protocol':([],[])}
specs=(('shellcheck',[b'-x',b'--severity=warning'],wanted[mode][0]),('shfmt',[b'-d',b'-i',b'2',b'-ci',b'-bn'],wanted[mode][1]),('gitleaks',[],[]))
for tool,prefix,paths in specs:
 if tool=='gitleaks': assert mode!='protocol' or not (root/tool).read_bytes(); continue
 records=[part.split(b'\0') for part in (root/tool).read_bytes().split(b'\0\0') if part]; assert records==[prefix+[path] for path in paths],(tool,records)
PY
}
prepare_path ''; install_ci_tools; run_static; assert_calls base || fail 'baseline static success: argv bytes'
assert_gitleaks() { "$host_python" - "$static_logs/gitleaks" "$static_fixture" "$repo_root/scripts/check.sh" <<'PY'
from pathlib import Path; import sys
records=[part.split(b'\0') for part in Path(sys.argv[1]).read_bytes().split(b'\0\0') if part]; repo=Path(sys.argv[2]).as_posix().encode(); config=repo+b'/.gitleaks.toml'
prefix=[b'GITLEAKS_CONFIG=unset',b'GITLEAKS_CONFIG_TOML=unset',b'dir',b'--no-banner',b'--redact',b'--exit-code',b'1',b'--config',config]
assert len(records)==2 and records[0][:-1]==prefix and records[1][:-1]==prefix and records[0][-1]!=repo and records[1][-1]==repo,records
source=Path(sys.argv[3]).read_text()
assert '>"$canary_dir/canary.txt" || quality_protocol_error' in source and 'if gitleaks "${gitleaks_args[@]}" "$canary_dir"; then' in source and 'rm -rf -- "$canary_dir" || quality_protocol_error' in source, 'explicit secret failure handling'
PY
}
no_total_pass() { ! grep -Fq 'RESULT PASS  aosp-harness offline quality gate' "$static_fixture/out"; }
[[ "$static_rc" -eq 0 && "$(tail -n 1 "$static_fixture/out")" == 'RESULT PASS  aosp-harness offline quality gate' ]] && assert_gitleaks || fail 'gitleaks config contract'
printf '\n# changed\n' >>"$static_fixture/$approved"; run_static
assert_calls changed || fail 'changed baseline pair: argv bytes'
for fail_tool in shellcheck shfmt; do run_static "$fail_tool"
  [[ "$static_rc" -eq 1 ]] || fail "$fail_tool finding: expected rc=1"
  assert_calls "$fail_tool" || fail "$fail_tool finding: calls after failure"
  [[ ! -s "$static_logs/gitleaks" ]] || fail "$fail_tool finding: gitleaks called"
  ! grep -Fq 'RESULT PASS  aosp-harness offline quality gate' "$static_fixture/out" || fail "$fail_tool finding: unexpected pass"
done
mutations=(append-current wrong-digest duplicate unsorted malformed non-anchor)
for mutation in "${mutations[@]}"; do cp "$baseline" "$static_fixture/scripts/shell-quality-baseline.tsv"; case "$mutation" in
  append-current) printf 'new.sh\t%s\n' "$(git -C "$static_fixture" hash-object new.sh)" >>"$static_fixture/scripts/shell-quality-baseline.tsv";;
  non-anchor) sed -i "1s/[0-9a-f]\{40\}$/$(git -C "$static_fixture" hash-object new.sh)/" "$static_fixture/scripts/shell-quality-baseline.tsv";;
  wrong-digest) sed -i '1s/[0-9a-f]$/0/' "$static_fixture/scripts/shell-quality-baseline.tsv";; duplicate) head -n 1 "$baseline" >>"$static_fixture/scripts/shell-quality-baseline.tsv";;
  unsorted) sed -i '1{h;d};2{G}' "$static_fixture/scripts/shell-quality-baseline.tsv";; malformed) printf 'bad\n' >>"$static_fixture/scripts/shell-quality-baseline.tsv";; esac
  case "$mutation" in append-current) [[ "$(wc -l <"$static_fixture/scripts/shell-quality-baseline.tsv")" -eq 31 ]] || fail 'baseline append-current: expected row 31';; non-anchor) baseline_valid "$static_fixture/scripts/shell-quality-baseline.tsv" || fail 'baseline non-anchor: fixture format';; esac
  run_static; [[ "$static_rc" -eq 2 ]] || fail "baseline $mutation: expected rc=2"
  assert_calls protocol || fail "baseline $mutation: tools called"; done
reset_secrets() { cp "$config" "$static_fixture/.gitleaks.toml"; cp "$repo_root/scripts/check.sh" "$baseline" "$static_fixture/scripts/"; }
for mutation in config-bytes config-digest empty-rules global-allowlist; do reset_secrets; case "$mutation" in config-bytes) printf '# changed\n' >>"$static_fixture/.gitleaks.toml";; config-digest) sed -i "s/$config_sha/$(printf '0%.0s' {1..64})/" "$static_fixture/scripts/check.sh";; empty-rules) : >"$static_fixture/.gitleaks.toml";; global-allowlist) printf '[allowlist]\npaths = [".*"]\n' >"$static_fixture/.gitleaks.toml";; esac; run_static; [[ "$static_rc" -eq 2 && ! -s "$static_logs/gitleaks" ]] && no_total_pass || fail "$mutation: expected config rc=2 without total pass"; done
reset_secrets; for canary_rc in 0 2; do run_static '' "$canary_rc"; [[ "$static_rc" -eq 2 && "$(grep -ao 'GITLEAKS_CONFIG=unset' "$static_logs/gitleaks" | wc -l)" -eq 1 ]] && no_total_pass || fail "canary rc $canary_rc: expected protocol failure without total pass"; done
mkdir "$static_fixture/in-repo-tmp"; run_static '' 1 0 "$static_fixture/in-repo-tmp"; [[ "$static_rc" -eq 2 && ! -s "$static_logs/gitleaks" ]] && no_total_pass || fail 'in-repo TMPDIR: expected zero gitleaks calls without total pass'
run_static '' 1 7; [[ "$static_rc" -eq 1 ]] && assert_gitleaks && no_total_pass || fail 'worktree gitleaks failure: expected rc=1 without total pass'
poison_log="$fixture/poison"; for name in shellcheck shfmt gitleaks adb cvd curl wget ssh repo ninja claude codex; do printf '#!%s\nprintf %s >>%q\nexit 88\n' "$host_bash" "$name" "$poison_log" >"$case_bin/$name"; chmod +x "$case_bin/$name"; done
before="$("$host_git" hash-object claude-code/CURRENT_FEATURE codex/CURRENT_FEATURE common/CURRENT_FEATURE)"; PATH="$case_bin:$PATH" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" ROOT_LOG="$root_log" BODY_LOG="$body_log" GIT_ALLOW_PROTOCOL=file "$host_python" - "$repo_root" "$host_bash" <<'PY'
import os,subprocess,sys
r=subprocess.run([sys.argv[2],'./scripts/check.sh','--offline'],cwd=sys.argv[1],env=os.environ.copy(),text=True,capture_output=True,timeout=30); assert r.returncode==0 and r.stdout.count('RESULT PASS  offline quality gate child')==1,(r.stdout,r.stderr)
PY
[[ ! -s "$poison_log" && "$before" == "$("$host_git" hash-object claude-code/CURRENT_FEATURE codex/CURRENT_FEATURE common/CURRENT_FEATURE)" ]] || fail 'real offline boundary'
printf 'RESULT PASS  offline quality gate contract\n'
