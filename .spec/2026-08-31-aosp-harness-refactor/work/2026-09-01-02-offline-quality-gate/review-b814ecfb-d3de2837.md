# review 包 b814ecfb..d3de2837

## commit 列表

```
d3de283 test(quality): cover CI preflight success path
```

## diff --stat

```
 tests/test-quality-gate.sh | 1 +
 1 file changed, 1 insertion(+)
```

## diff

```diff
diff --git a/tests/test-quality-gate.sh b/tests/test-quality-gate.sh
index cc4a0d2..bb038cc 100755
--- a/tests/test-quality-gate.sh
+++ b/tests/test-quality-gate.sh
@@ -16,20 +16,21 @@ prepare_path() { local missing="$1" c; rm -rf -- "$case_bin"; mkdir "$case_bin";
 run_error() { local label="$1" needle="$2" missing="$3" rc; shift 3; prepare_path "$missing"; : >"$syntax_marker"; : >"$test_marker"; set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" TEST_MARKER="$test_marker" "$host_bash" "$fixture/scripts/check.sh" "$@" >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e; [[ "$rc" -eq 2 ]] || fail "$label: expected rc=2"; grep -Fq "$needle" "$fixture/err" || fail "$label: expected $needle"; [[ ! -s "$syntax_marker" && ! -s "$test_marker" ]] || fail "$label: markers ran"; ! grep -Fq 'RESULT PASS  aosp-harness offline quality gate' "$fixture/out" || fail "$label: unexpected pass"; }
 run_error 'cli no-argument' usage -
 run_error 'cli unknown' usage - --unknown
 run_error 'cli extra' usage - --offline extra
 for missing in "${required[@]}"; do run_error "missing $missing" "missing required command: $missing" "$missing" --offline; done
 tool_cases=(shellcheck:0.11.0 shfmt:3.14.0 gitleaks:8.30.1)
 fake_tool() { local tool="$1" response="$2"; printf '#!%s\ncase "$1" in --version|version) printf "%%s\\n" %q;; *) exit 90;; esac\n' "$host_bash" "$response" >"$case_bin/$tool"; chmod +x "$case_bin/$tool"; }
 install_ci_tools() { local spec tool version; for spec in "${tool_cases[@]}"; do tool="${spec%%:*}"; version="${spec#*:}"; case "$tool" in shellcheck) fake_tool "$tool" "version: $version";; shfmt) fake_tool "$tool" "v$version";; gitleaks) fake_tool "$tool" "$version";; esac; done; }
 run_ci_error() { local label="$1" tool="$2" version="$3" state="$4" rc; prepare_path ''; install_ci_tools; [[ "$state" == missing ]] && rm "$case_bin/$tool" || fake_tool "$tool" wrong; : >"$syntax_marker"; : >"$test_marker"; set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" TEST_MARKER="$test_marker" "$host_bash" "$fixture/scripts/check.sh" --ci >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e; [[ "$rc" -eq 2 && ! -s "$syntax_marker" && ! -s "$test_marker" ]] || fail "ci $tool $state: expected rc=2 before core"; grep -Fq "$tool" "$fixture/err" && grep -Fq "$version" "$fixture/err" || fail "ci $tool $state: expected version"; ! grep -Fq 'RESULT PASS  aosp-harness offline quality gate' "$fixture/out" || fail "ci $tool $state: unexpected pass"; }
 for spec in "${tool_cases[@]}"; do tool="${spec%%:*}"; version="${spec#*:}"; run_ci_error "$tool" "$tool" "$version" missing; run_ci_error "$tool" "$tool" "$version" wrong; done
+prepare_path ''; install_ci_tools; : >"$syntax_marker"; : >"$test_marker"; set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" TEST_MARKER="$test_marker" "$host_bash" "$fixture/scripts/check.sh" --ci >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e; [[ "$rc" -eq 1 && -s "$syntax_marker" && ! -s "$test_marker" ]] || fail 'ci correct tools: expected core syntax failure'; ! grep -Fq 'RESULT PASS  aosp-harness offline quality gate' "$fixture/out" || fail 'ci correct tools: unexpected pass'
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
```
