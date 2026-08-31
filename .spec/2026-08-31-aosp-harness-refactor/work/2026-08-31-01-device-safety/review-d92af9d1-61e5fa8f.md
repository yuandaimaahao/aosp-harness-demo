# review 包 d92af9d1..61e5fa8f

## commit 列表

```
61e5fa8 test: aggregate device safety regressions
```

## diff --stat

```
 tests/test-device-safety.sh | 31 ++++++++++++++++++++++++++++++-
 1 file changed, 30 insertions(+), 1 deletion(-)
```

## diff

```diff
diff --git a/tests/test-device-safety.sh b/tests/test-device-safety.sh
index fb57e03..1e96048 100755
--- a/tests/test-device-safety.sh
+++ b/tests/test-device-safety.sh
@@ -700,38 +700,67 @@ device_safety_run_skill_contract_selftest() {
 
   device_safety_write_synthetic_skill "$redirect_path" \
     'adb -s "$device_serial" root; adb>/tmp/adb.out' safe
   device_safety_expect_synthetic_skill_rejection redirect-adb "$redirect_path"
 
   device_safety_write_synthetic_skill "$append_path" \
     'adb -s "$device_serial" root' append
   device_safety_expect_synthetic_skill_rejection append-serial "$append_path"
 }
 
+device_safety_run_legacy() {
+  local legacy_tests legacy_test fake_bin
+
+  device_safety_fake_adb_install legacy demo-serial
+  fake_bin="$DEVICE_SAFETY_FAKE_BIN"
+  legacy_tests=(
+    './claude-code/features/.harness/tests/test-harness.sh'
+    './codex/tests/test-harness.sh'
+    './common/tests/test-harness.sh'
+  )
+
+  for legacy_test in "${legacy_tests[@]}"; do
+    PATH="$fake_bin:$PATH" bash "$legacy_test" ||
+      device_safety_fail "legacy failed: $legacy_test"
+  done
+}
+
+device_safety_run_all() {
+  local scope
+
+  for scope in fixture claude-invalid-serial claude-valid-serial flag-demo skills legacy; do
+    device_safety_run_scope "$scope" || return $?
+    [[ "$DEVICE_SAFETY_FAILURES" -eq 0 ]] || return 1
+  done
+}
+
 main() {
   local scope
 
   if [[ "$#" -ne 0 ]]; then
     printf 'error: test-device-safety.sh accepts no positional arguments\n' >&2
     return 2
   fi
 
   DEVICE_SAFETY_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/device-safety.XXXXXX")" || return 1
   trap device_safety_cleanup EXIT
 
-  scope="${DEVICE_SAFETY_TEST_SCOPE:-fixture}"
+  scope="${DEVICE_SAFETY_TEST_SCOPE:-all}"
   device_safety_run_scope "$scope" || return $?
   [[ "$DEVICE_SAFETY_FAILURES" -eq 0 ]] || return 1
+  [[ "$scope" != all ]] || printf 'RESULT PASS  device safety\n'
 }
 
 device_safety_register_scope fixture device_safety_run_fixture
 device_safety_register_scope claude-invalid-serial device_safety_run_claude_invalid_serial_matrix
 device_safety_register_scope claude-valid-serial device_safety_run_claude_valid_serial_matrix
 device_safety_register_scope claude-flag-demo device_safety_run_claude_flag_demo_matrix
 device_safety_register_scope codex-flag-demo device_safety_run_codex_flag_demo_matrix
 device_safety_register_scope flag-demo device_safety_run_flag_and_demo_matrix
 device_safety_register_scope skill-blocks device_safety_run_skill_blocks
 device_safety_register_scope skill-contract device_safety_run_skill_contract
 device_safety_register_scope skill-contract-selftest device_safety_run_skill_contract_selftest
 device_safety_register_scope mutation-selftest device_safety_run_skill_mutation_selftest
 device_safety_register_scope skills device_safety_run_skills
+device_safety_register_scope legacy device_safety_run_legacy
+device_safety_register_scope all device_safety_run_all
 main "$@"
```
