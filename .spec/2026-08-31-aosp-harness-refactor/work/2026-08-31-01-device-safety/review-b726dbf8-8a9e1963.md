# review 包 b726dbf8..8a9e1963

## commit 列表

```
8a9e196 test: add skill device target contract oracle
```

## diff --stat

```
 tests/test-device-safety.sh | 49 +++++++++++++++++++++++++++++++++++++++++++++
 1 file changed, 49 insertions(+)
```

## diff

```diff
diff --git a/tests/test-device-safety.sh b/tests/test-device-safety.sh
index 6652745..6302358 100755
--- a/tests/test-device-safety.sh
+++ b/tests/test-device-safety.sh
@@ -328,20 +328,68 @@ device_safety_run_skill_blocks() {
     skill_blocks="$fixture_dir/$skill_name"
     extracted_count="$(device_safety_extract_device_blocks "$skill_name" "$skill_path" "$skill_blocks")" || {
       device_safety_fail "$skill_name: failed to extract fenced device blocks"
       continue
     }
     [[ "$extracted_count" == 1 ]] ||
       device_safety_fail "$skill_name: expected exactly one fenced device block"
   done
 }
 
+device_safety_check_skill_file() {
+  local skill_name="$1" path="$2" blocks_dir extracted_count block
+  local serial_line regex_line first_adb serial_at regex_at expected_prefix
+  local adb_line trimmed adb_count=0
+
+  blocks_dir="$DEVICE_SAFETY_TMPDIR/skill-contract-$skill_name"
+  extracted_count="$(device_safety_extract_device_blocks "$skill_name" "$path" "$blocks_dir")" || {
+    device_safety_fail "$skill_name: failed to extract fenced device blocks"
+    return
+  }
+  [[ "$extracted_count" == 1 ]] || {
+    device_safety_fail "$skill_name: expected exactly one fenced device block"
+    return
+  }
+
+  block="$blocks_dir/block-1.bash"
+  serial_line='device_serial="${ANDROID_SERIAL-}"'
+  regex_line='if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then'
+  first_adb="$(grep -nEm1 '(^|[;&][[:space:]]*)adb[[:space:]]' "$block" | cut -d: -f1)"
+  serial_at="$(grep -nFm1 "$serial_line" "$block" | cut -d: -f1)"
+  regex_at="$(grep -nFm1 "$regex_line" "$block" | cut -d: -f1)"
+  if [[ -z "$first_adb" || -z "$serial_at" || -z "$regex_at" ||
+    "$serial_at" -ge "$first_adb" || "$regex_at" -ge "$first_adb" ]]; then
+    device_safety_fail "$skill_name device block 1: missing safe serial preflight"
+    return
+  fi
+
+  expected_prefix='adb -s "$device_serial" '
+  while IFS= read -r adb_line; do
+    adb_count=$((adb_count + 1))
+    trimmed="${adb_line#"${adb_line%%[![:space:]]*}"}"
+    [[ "$trimmed" == "$expected_prefix"* ]] || {
+      device_safety_fail "$skill_name device block 1: bare adb"
+      return
+    }
+  done < <(grep -E 'adb[[:space:]].*(root|remount|push|reboot|shell)' "$block")
+
+  [[ "$adb_count" -gt 0 ]] ||
+    device_safety_fail "$skill_name device block 1: bare adb"
+}
+
+device_safety_run_skill_contract() {
+  device_safety_check_skill_file \
+    build-services-jar ./claude-code/features/.harness/skills/build-services-jar/SKILL.md
+  device_safety_check_skill_file \
+    build-sepolicy ./claude-code/features/.harness/skills/build-sepolicy/SKILL.md
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
@@ -351,11 +399,12 @@ main() {
   [[ "$DEVICE_SAFETY_FAILURES" -eq 0 ]] || return 1
 }
 
 device_safety_register_scope fixture device_safety_run_fixture
 device_safety_register_scope claude-invalid-serial device_safety_run_claude_invalid_serial_matrix
 device_safety_register_scope claude-valid-serial device_safety_run_claude_valid_serial_matrix
 device_safety_register_scope claude-flag-demo device_safety_run_claude_flag_demo_matrix
 device_safety_register_scope codex-flag-demo device_safety_run_codex_flag_demo_matrix
 device_safety_register_scope flag-demo device_safety_run_flag_and_demo_matrix
 device_safety_register_scope skill-blocks device_safety_run_skill_blocks
+device_safety_register_scope skill-contract device_safety_run_skill_contract
 main "$@"
```
