#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)"; host_bash="$(command -v bash)"
[[ "$host_bash" == /* && -x "$host_bash" ]] || exit 99
fixture="$(mktemp -d)"; trap 'rm -rf -- "$fixture"' EXIT
git init -q "$fixture"; mkdir -p "$fixture/scripts" "$fixture/tests"
cp "$repo_root/scripts/check.sh" "$fixture/scripts/check.sh" 2>/dev/null || :
printf 'if then\n' >"$fixture/bad.sh"; printf '#!/usr/bin/env bash\nprintf test >>"$TEST_MARKER"\n' >"$fixture/tests/test-marker.sh"
required=(bash git python3 rg find sort awk sed grep sha256sum); case_bin="$fixture/bin"; syntax_marker="$fixture/syntax"; test_marker="$fixture/test"
fail() { printf 'FAIL  %s\n' "$1"; exit 1; }
prepare_path() { local missing="$1" c; rm -rf -- "$case_bin"; mkdir "$case_bin"; for c in "${required[@]}"; do [[ "$c" == "$missing" ]] || ln -s "$(command -v "$c")" "$case_bin/$c"; done; }
run_error() { local label="$1" needle="$2" missing="$3" rc; shift 3; prepare_path "$missing"; : >"$syntax_marker"; : >"$test_marker"; set +e; PATH="$case_bin" "$host_bash" "$fixture/scripts/check.sh" "$@" >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e; [[ "$rc" -eq 2 ]] || fail "$label: expected rc=2"; grep -Fq "$needle" "$fixture/err" || fail "$label: expected $needle"; [[ ! -s "$syntax_marker" && ! -s "$test_marker" ]] || fail "$label: markers ran"; ! grep -Fq 'RESULT PASS  aosp-harness offline quality gate' "$fixture/out" || fail "$label: unexpected pass"; }
run_error 'cli no-argument' usage -
run_error 'cli unknown' usage - --unknown
run_error 'cli extra' usage - --offline extra
for missing in "${required[@]}"; do run_error "missing $missing" "missing required command: $missing" "$missing" --offline; done
prepare_path ''; set +e; PATH="$case_bin" "$host_bash" "$fixture/scripts/check.sh" --offline >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e
[[ "$rc" -eq 0 ]] || fail 'offline success: expected rc=0'
[[ "$(tail -n 1 "$fixture/out")" == 'RESULT PASS  aosp-harness offline quality gate' ]] || fail 'offline success: expected pass line'
printf 'RESULT PASS  offline quality gate contract\n'
