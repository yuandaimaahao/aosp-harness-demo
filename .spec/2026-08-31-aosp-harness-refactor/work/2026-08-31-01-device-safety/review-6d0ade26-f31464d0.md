# review 包 6d0ade26..f31464d0

## commit 列表

```
f31464d test: add Claude valid serial matrix
```

## diff --stat

```
 tests/test-device-safety.sh | 30 ++++++++++++++++++++++++++++++
 1 file changed, 30 insertions(+)
```

## diff

```diff
diff --git a/tests/test-device-safety.sh b/tests/test-device-safety.sh
index 68dd86e..a9118b7 100755
--- a/tests/test-device-safety.sh
+++ b/tests/test-device-safety.sh
@@ -149,29 +149,59 @@ device_safety_run_claude_invalid_serial_matrix() {
     fi
     rc=$?
 
     [[ "$rc" -eq 2 ]] || device_safety_fail "$label: expected rc=2 and zero adb calls"
     grep -Fq 'ANDROID_SERIAL' "$stderr_file" ||
       device_safety_fail "$label: missing ANDROID_SERIAL error"
     [[ ! -s "$adb_log" ]] || device_safety_fail "$label: expected zero adb calls"
   done
 }
 
+device_safety_run_claude_valid_serial_matrix() {
+  local valid_serials serial fixture_dir stderr_file stdout_file adb_log expected_prefix rc
+  local case_index=0
+
+  valid_serials=('demo-serial' 'A0._:-z')
+
+  for serial in "${valid_serials[@]}"; do
+    case_index=$((case_index + 1))
+    device_safety_fake_adb_install "claude-valid-$case_index" "$serial"
+    fixture_dir="$DEVICE_SAFETY_TMPDIR/claude-valid-$case_index"
+    stderr_file="$fixture_dir/stderr"
+    stdout_file="$fixture_dir/stdout"
+    adb_log="$ADB_LOG"
+    expected_prefix="adb -s $serial "
+
+    ANDROID_SERIAL="$serial" PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" \
+      bash ./claude-code/features/dev-sidebar/verify-sidebar.sh --since 200 \
+      >"$stdout_file" 2>"$stderr_file"
+    rc=$?
+
+    [[ -s "$adb_log" ]] ||
+      device_safety_fail "claude $serial: expected non-empty adb log"
+    [[ "$(grep -Fvc "$expected_prefix" "$adb_log")" -eq 0 ]] ||
+      device_safety_fail "claude $serial: expected adb -s prefix on every call"
+    [[ "$rc" -eq 0 && "$(tail -n 1 "$stdout_file")" == 'RESULT PASS' ]] ||
+      device_safety_fail "claude $serial: expected rc=0 and RESULT PASS"
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
 
   scope="${DEVICE_SAFETY_TEST_SCOPE:-fixture}"
   device_safety_run_scope "$scope" || return $?
   [[ "$DEVICE_SAFETY_FAILURES" -eq 0 ]] || return 1
 }
 
 device_safety_register_scope fixture device_safety_run_fixture
 device_safety_register_scope claude-invalid-serial device_safety_run_claude_invalid_serial_matrix
+device_safety_register_scope claude-valid-serial device_safety_run_claude_valid_serial_matrix
 main "$@"
```
