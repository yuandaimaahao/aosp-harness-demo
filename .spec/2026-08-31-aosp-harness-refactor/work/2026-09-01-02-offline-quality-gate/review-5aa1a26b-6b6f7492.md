# review 包 5aa1a26b..6b6f7492

## commit 列表

```
6b6f749 test(quality): harden gate preflight contract
```

## diff --stat

```
 tests/test-quality-gate.sh | 15 ++++++++++++---
 1 file changed, 12 insertions(+), 3 deletions(-)
```

## diff

```diff
diff --git a/tests/test-quality-gate.sh b/tests/test-quality-gate.sh
index 150ce38..8a0613e 100755
--- a/tests/test-quality-gate.sh
+++ b/tests/test-quality-gate.sh
@@ -1,20 +1,29 @@
 #!/usr/bin/env bash
 set -euo pipefail
 repo_root="$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)"; host_bash="$(command -v bash)"
 [[ "$host_bash" == /* && -x "$host_bash" ]] || exit 99
+if [[ "${QUALITY_GATE_NESTED-}" == 1 ]]; then
+  printf 'RESULT PASS  offline quality gate child\n'
+  exit 0
+fi
 fixture="$(mktemp -d)"; trap 'rm -rf -- "$fixture"' EXIT
 git init -q "$fixture"; mkdir -p "$fixture/scripts" "$fixture/tests"
 cp "$repo_root/scripts/check.sh" "$fixture/scripts/check.sh" 2>/dev/null || :
 printf 'if then\n' >"$fixture/bad.sh"; printf '#!/usr/bin/env bash\nprintf test >>"$TEST_MARKER"\n' >"$fixture/tests/test-marker.sh"
 required=(bash git python3 rg find sort awk sed grep sha256sum); case_bin="$fixture/bin"; syntax_marker="$fixture/syntax"; test_marker="$fixture/test"
 fail() { printf 'FAIL  %s\n' "$1"; exit 1; }
-prepare_path() { local missing="$1" c; rm -rf -- "$case_bin"; mkdir "$case_bin"; for c in "${required[@]}"; do [[ "$c" == "$missing" ]] || ln -s "$(command -v "$c")" "$case_bin/$c"; done; }
-run_error() { local label="$1" needle="$2" missing="$3" rc; shift 3; prepare_path "$missing"; : >"$syntax_marker"; : >"$test_marker"; set +e; PATH="$case_bin" "$host_bash" "$fixture/scripts/check.sh" "$@" >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e; [[ "$rc" -eq 2 ]] || fail "$label: expected rc=2"; grep -Fq "$needle" "$fixture/err" || fail "$label: expected $needle"; [[ ! -s "$syntax_marker" && ! -s "$test_marker" ]] || fail "$label: markers ran"; ! grep -Fq 'RESULT PASS  aosp-harness offline quality gate' "$fixture/out" || fail "$label: unexpected pass"; }
+prepare_path() { local missing="$1" c; rm -rf -- "$case_bin"; mkdir "$case_bin"; for c in "${required[@]}"; do [[ "$c" == "$missing" ]] || { if [[ "$c" == bash ]]; then printf '#!%s\n[[ "$1" == -n ]] && printf x >>"$SYNTAX_MARKER"\nexec "$HOST_BASH" "$@"\n' "$host_bash" >"$case_bin/bash"; chmod +x "$case_bin/bash"; else ln -s "$(command -v "$c")" "$case_bin/$c"; fi; }; done; }
+run_error() { local label="$1" needle="$2" missing="$3" rc; shift 3; prepare_path "$missing"; : >"$syntax_marker"; : >"$test_marker"; set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" TEST_MARKER="$test_marker" "$host_bash" "$fixture/scripts/check.sh" "$@" >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e; [[ "$rc" -eq 2 ]] || fail "$label: expected rc=2"; grep -Fq "$needle" "$fixture/err" || fail "$label: expected $needle"; [[ ! -s "$syntax_marker" && ! -s "$test_marker" ]] || fail "$label: markers ran"; ! grep -Fq 'RESULT PASS  aosp-harness offline quality gate' "$fixture/out" || fail "$label: unexpected pass"; }
 run_error 'cli no-argument' usage -
 run_error 'cli unknown' usage - --unknown
 run_error 'cli extra' usage - --offline extra
 for missing in "${required[@]}"; do run_error "missing $missing" "missing required command: $missing" "$missing" --offline; done
-prepare_path ''; set +e; PATH="$case_bin" "$host_bash" "$fixture/scripts/check.sh" --offline >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e
+prepare_path ''; : >"$syntax_marker"; set +e; HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" "$case_bin/bash" -n "$fixture/bad.sh" >/dev/null 2>&1; syntax_rc=$?; set -e
+[[ "$syntax_rc" -eq 2 && -s "$syntax_marker" ]] || fail 'fake bash: expected syntax marker'
+: >"$test_marker"; TEST_MARKER="$test_marker" "$host_bash" "$fixture/tests/test-marker.sh"
+[[ -s "$test_marker" ]] || fail 'root test: expected marker'
+[[ "$(QUALITY_GATE_NESTED=1 "$host_bash" "${BASH_SOURCE[0]}")" == 'RESULT PASS  offline quality gate child' ]] || fail 'nested: expected child pass'
+prepare_path ''; set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" TEST_MARKER="$test_marker" "$host_bash" "$fixture/scripts/check.sh" --offline >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e
 [[ "$rc" -eq 0 ]] || fail 'offline success: expected rc=0'
 [[ "$(tail -n 1 "$fixture/out")" == 'RESULT PASS  aosp-harness offline quality gate' ]] || fail 'offline success: expected pass line'
 printf 'RESULT PASS  offline quality gate contract\n'
```
