# review 包 c7ef909b..b814ecfb

## commit 列表

```
b814ecf feat(quality): preflight CI tool versions
```

## diff --stat

```
 scripts/check.sh           | 11 +++++++++++
 tests/test-quality-gate.sh |  5 +++++
 2 files changed, 16 insertions(+)
```

## diff

```diff
diff --git a/scripts/check.sh b/scripts/check.sh
index a08408d..d3bbce8 100755
--- a/scripts/check.sh
+++ b/scripts/check.sh
@@ -20,12 +20,23 @@ quality_list_shell_files() {
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
+if [[ "$mode" == --ci ]]; then
+  for tool_spec in shellcheck:0.11.0 shfmt:3.14.0 gitleaks:8.30.1; do
+    tool="${tool_spec%%:*}"; expected="${tool_spec#*:}"
+    command -v "$tool" >/dev/null 2>&1 || quality_protocol_error "missing $tool $expected"
+    case "$tool" in
+      shellcheck) [[ "$(shellcheck --version | awk '/^version:/ {print $2}')" == 0.11.0 ]] || quality_protocol_error 'expected shellcheck 0.11.0' ;;
+      shfmt) [[ "$(shfmt --version)" == v3.14.0 ]] || quality_protocol_error 'expected shfmt 3.14.0' ;;
+      gitleaks) [[ "$(gitleaks version)" == 8.30.1 ]] || quality_protocol_error 'expected gitleaks 8.30.1' ;;
+    esac
+  done
+fi
 quality_run_core || exit 1
 printf 'RESULT PASS  aosp-harness offline quality gate\n'
diff --git a/tests/test-quality-gate.sh b/tests/test-quality-gate.sh
index 4fed341..cc4a0d2 100755
--- a/tests/test-quality-gate.sh
+++ b/tests/test-quality-gate.sh
@@ -11,20 +11,25 @@ git init -q "$fixture"; mkdir -p "$fixture/scripts" "$fixture/tests"
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
+tool_cases=(shellcheck:0.11.0 shfmt:3.14.0 gitleaks:8.30.1)
+fake_tool() { local tool="$1" response="$2"; printf '#!%s\ncase "$1" in --version|version) printf "%%s\\n" %q;; *) exit 90;; esac\n' "$host_bash" "$response" >"$case_bin/$tool"; chmod +x "$case_bin/$tool"; }
+install_ci_tools() { local spec tool version; for spec in "${tool_cases[@]}"; do tool="${spec%%:*}"; version="${spec#*:}"; case "$tool" in shellcheck) fake_tool "$tool" "version: $version";; shfmt) fake_tool "$tool" "v$version";; gitleaks) fake_tool "$tool" "$version";; esac; done; }
+run_ci_error() { local label="$1" tool="$2" version="$3" state="$4" rc; prepare_path ''; install_ci_tools; [[ "$state" == missing ]] && rm "$case_bin/$tool" || fake_tool "$tool" wrong; : >"$syntax_marker"; : >"$test_marker"; set +e; PATH="$case_bin" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" TEST_MARKER="$test_marker" "$host_bash" "$fixture/scripts/check.sh" --ci >"$fixture/out" 2>"$fixture/err"; rc=$?; set -e; [[ "$rc" -eq 2 && ! -s "$syntax_marker" && ! -s "$test_marker" ]] || fail "ci $tool $state: expected rc=2 before core"; grep -Fq "$tool" "$fixture/err" && grep -Fq "$version" "$fixture/err" || fail "ci $tool $state: expected version"; ! grep -Fq 'RESULT PASS  aosp-harness offline quality gate' "$fixture/out" || fail "ci $tool $state: unexpected pass"; }
+for spec in "${tool_cases[@]}"; do tool="${spec%%:*}"; version="${spec#*:}"; run_ci_error "$tool" "$tool" "$version" missing; run_ci_error "$tool" "$tool" "$version" wrong; done
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
