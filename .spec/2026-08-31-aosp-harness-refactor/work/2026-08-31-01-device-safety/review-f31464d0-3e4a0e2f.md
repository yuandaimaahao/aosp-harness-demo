# review 包 f31464d0..3e4a0e2f

## commit 列表

```
3e4a0e2 test: anchor Claude adb log prefix checks
```

## diff --stat

```
 tests/test-device-safety.sh | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

## diff

```diff
diff --git a/tests/test-device-safety.sh b/tests/test-device-safety.sh
index a9118b7..73b34ca 100755
--- a/tests/test-device-safety.sh
+++ b/tests/test-device-safety.sh
@@ -171,21 +171,21 @@ device_safety_run_claude_valid_serial_matrix() {
     adb_log="$ADB_LOG"
     expected_prefix="adb -s $serial "
 
     ANDROID_SERIAL="$serial" PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" \
       bash ./claude-code/features/dev-sidebar/verify-sidebar.sh --since 200 \
       >"$stdout_file" 2>"$stderr_file"
     rc=$?
 
     [[ -s "$adb_log" ]] ||
       device_safety_fail "claude $serial: expected non-empty adb log"
-    [[ "$(grep -Fvc "$expected_prefix" "$adb_log")" -eq 0 ]] ||
+    awk -v prefix="$expected_prefix" 'index($0, prefix) != 1 { exit 1 }' "$adb_log" ||
       device_safety_fail "claude $serial: expected adb -s prefix on every call"
     [[ "$rc" -eq 0 && "$(tail -n 1 "$stdout_file")" == 'RESULT PASS' ]] ||
       device_safety_fail "claude $serial: expected rc=0 and RESULT PASS"
   done
 }
 
 main() {
   local scope
 
   if [[ "$#" -ne 0 ]]; then
```
