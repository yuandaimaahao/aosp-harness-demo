# review 包 782387ab..6d0ade26

## commit 列表

```
6d0ade2 test: add Claude invalid serial matrix
```

## diff --stat

```
 tests/test-device-safety.sh | 40 ++++++++++++++++++++++++++++++++++++++++
 1 file changed, 40 insertions(+)
```

## diff

```diff
diff --git a/tests/test-device-safety.sh b/tests/test-device-safety.sh
index f599fe2..68dd86e 100755
--- a/tests/test-device-safety.sh
+++ b/tests/test-device-safety.sh
@@ -110,28 +110,68 @@ device_safety_run_fixture() {
   grep -Fq 'adb -s demo-serial shell getprop sys.boot_completed ' "$ADB_LOG" ||
     device_safety_fail 'fixture: adb log must include command name'
   grep -Fq 'adb -s demo-serial logcat -b crash -d -v threadtime -T 200 ' "$ADB_LOG" ||
     device_safety_fail 'fixture: adb log must include logcat command name'
   grep -Fq 'adb -s other-serial shell getprop sys.boot_completed ' "$ADB_LOG" ||
     device_safety_fail 'fixture: adb log must include rejected serial command'
   grep -Fq 'adb -s demo-serial unknown command ' "$ADB_LOG" ||
     device_safety_fail 'fixture: adb log must include rejected unknown command'
 }
 
+device_safety_run_claude_invalid_serial_matrix() {
+  local invalid_serials serial case_name fixture_dir stderr_file stdout_file adb_log label rc
+  local case_index=0
+
+  invalid_serials=(
+    '__UNSET__' '-bad' '.bad' '_bad' ':bad' 'bad/path' 'bad value'
+    $'bad\nvalue' 'bad;value' 'bad+value'
+  )
+
+  for serial in "${invalid_serials[@]}"; do
+    case_index=$((case_index + 1))
+    case_name="$serial"
+    [[ "$serial" != '__UNSET__' ]] || case_name='missing'
+    label="claude $case_name ANDROID_SERIAL"
+
+    device_safety_fake_adb_install "claude-invalid-$case_index" demo-serial
+    fixture_dir="$DEVICE_SAFETY_TMPDIR/claude-invalid-$case_index"
+    stderr_file="$fixture_dir/stderr"
+    stdout_file="$fixture_dir/stdout"
+    adb_log="$ADB_LOG"
+
+    if [[ "$serial" == '__UNSET__' ]]; then
+      env -u ANDROID_SERIAL PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" \
+        bash ./claude-code/features/dev-sidebar/verify-sidebar.sh \
+        >"$stdout_file" 2>"$stderr_file"
+    else
+      ANDROID_SERIAL="$serial" PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" \
+        bash ./claude-code/features/dev-sidebar/verify-sidebar.sh \
+        >"$stdout_file" 2>"$stderr_file"
+    fi
+    rc=$?
+
+    [[ "$rc" -eq 2 ]] || device_safety_fail "$label: expected rc=2 and zero adb calls"
+    grep -Fq 'ANDROID_SERIAL' "$stderr_file" ||
+      device_safety_fail "$label: missing ANDROID_SERIAL error"
+    [[ ! -s "$adb_log" ]] || device_safety_fail "$label: expected zero adb calls"
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
+device_safety_register_scope claude-invalid-serial device_safety_run_claude_invalid_serial_matrix
 main "$@"
```
