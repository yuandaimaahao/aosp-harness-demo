# review 包 cab162d9..1c49ee42

## commit 列表

```
1c49ee4 test: close skill oracle parsing gaps
```

## diff --stat

```
 tests/test-device-safety.sh | 149 +++++++++++++++++++++++++++++++++-----------
 1 file changed, 111 insertions(+), 38 deletions(-)
```

## diff

```diff
diff --git a/tests/test-device-safety.sh b/tests/test-device-safety.sh
index ffb6ed0..926e280 100755
--- a/tests/test-device-safety.sh
+++ b/tests/test-device-safety.sh
@@ -331,134 +331,207 @@ device_safety_run_skill_blocks() {
       continue
     }
     [[ "$extracted_count" == 1 ]] ||
       device_safety_fail "$skill_name: expected exactly one fenced device block"
   done
 }
 
 device_safety_check_skill_file() {
   local skill_name="$1" path="$2" blocks_dir extracted_count block
   local serial_line regex_line first_adb serial_at regex_at serial_count regex_count
-  local expected_prefix adb_line trimmed adb_count adb_tokens adb_token_count
+  local expected_prefix line trimmed line_number=0 adb_count adb_contract_valid adb_tokens adb_token_count
 
   blocks_dir="$DEVICE_SAFETY_TMPDIR/skill-contract-$skill_name"
   extracted_count="$(device_safety_extract_device_blocks "$skill_name" "$path" "$blocks_dir")" || {
     device_safety_fail "$skill_name: failed to extract fenced device blocks"
     return 1
   }
   [[ "$extracted_count" == 1 ]] || {
     device_safety_fail "$skill_name: expected exactly one fenced device block"
     return 1
   }
 
   block="$blocks_dir/block-1.bash"
   serial_line='device_serial="${ANDROID_SERIAL-}"'
   regex_line='if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then'
-  first_adb="$(grep -nEm1 '(^|[^[:alnum:]_])adb($|[[:space:]])' "$block" | cut -d: -f1)"
-  serial_at="$(grep -nFm1 "$serial_line" "$block" | cut -d: -f1)"
-  regex_at="$(grep -nFm1 "$regex_line" "$block" | cut -d: -f1)"
-  serial_count="$(grep -Foc "$serial_line" "$block")"
-  regex_count="$(grep -Foc "$regex_line" "$block")"
-  if [[ "$serial_count" != 1 || "$regex_count" != 1 ||
+  first_adb=''
+  serial_at=''
+  regex_at=''
+  serial_count=0
+  regex_count=0
+  adb_count=0
+  adb_contract_valid=1
+  expected_prefix='adb -s "$device_serial" '
+  while IFS= read -r line || [[ -n "$line" ]]; do
+    line_number=$((line_number + 1))
+    trimmed="${line#"${line%%[![:space:]]*}"}"
+    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
+    [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue
+
+    if [[ "$trimmed" == "$serial_line" ]]; then
+      serial_count=$((serial_count + 1))
+      serial_at="$line_number"
+    elif [[ "$trimmed" =~ device_serial[[:space:]]*= ]]; then
+      device_safety_fail "$skill_name device block 1: device_serial reassignment"
+      return 1
+    fi
+    if [[ "$trimmed" == "$regex_line" ]]; then
+      regex_count=$((regex_count + 1))
+      regex_at="$line_number"
+    fi
+
+    adb_tokens="$(grep -oE '(^|[[:space:];|&()])adb($|[[:space:];|&()])' <<<"$trimmed")"
+    adb_token_count="$(grep -c . <<<"$adb_tokens")"
+    [[ "$adb_token_count" -eq 0 ]] && continue
+    [[ -n "$first_adb" ]] || first_adb="$line_number"
+    adb_count=$((adb_count + adb_token_count))
+    [[ "$adb_token_count" -eq 1 && "$trimmed" == "$expected_prefix"* ]] ||
+      adb_contract_valid=0
+  done <"$block"
+
+  if [[ "$serial_count" -ne 1 || "$regex_count" -ne 1 ||
     -z "$first_adb" || -z "$serial_at" || -z "$regex_at" ||
     "$serial_at" -ge "$first_adb" || "$regex_at" -ge "$first_adb" ]]; then
     device_safety_fail "$skill_name device block 1: missing safe serial preflight"
     return 1
   fi
 
-  expected_prefix='adb -s "$device_serial" '
-  adb_count=0
-  while IFS= read -r adb_line; do
-    adb_tokens="$(grep -oE '(^|[^[:alnum:]_])adb($|[[:space:]])' <<<"$adb_line")"
-    adb_token_count="$(grep -c . <<<"$adb_tokens")"
-    adb_count=$((adb_count + adb_token_count))
-    trimmed="${adb_line#"${adb_line%%[![:space:]]*}"}"
-    [[ "$adb_token_count" -eq 1 && "$trimmed" == "$expected_prefix"* ]] || {
-      device_safety_fail "$skill_name device block 1: bare adb"
-      return 1
-    }
-  done < <(grep -E '(^|[^[:alnum:]_])adb($|[[:space:]])' "$block")
-
-  [[ "$adb_count" -gt 0 ]] || {
+  [[ "$adb_count" -gt 0 && "$adb_contract_valid" -eq 1 ]] || {
     device_safety_fail "$skill_name device block 1: bare adb"
     return 1
   }
 }
 
 device_safety_run_skill_contract() {
   device_safety_check_skill_file \
     build-services-jar ./claude-code/features/.harness/skills/build-services-jar/SKILL.md
   device_safety_check_skill_file \
     build-sepolicy ./claude-code/features/.harness/skills/build-sepolicy/SKILL.md
 }
 
 device_safety_write_synthetic_skill() {
-  local path="$1" adb_line="$2" repeat_preflight="${3:-0}"
-
-  printf '%s\n' \
-    '# synthetic skill' \
-    '```bash' \
-    'device_serial="${ANDROID_SERIAL-}"' \
-    'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
-    '  exit 2' \
-    'fi' >"$path"
-  if [[ "$repeat_preflight" -eq 1 ]]; then
-    printf '%s\n' \
-      'device_serial="${ANDROID_SERIAL-}"' \
-      'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
-      '  exit 2' \
-      'fi' >>"$path"
-  fi
+  local path="$1" adb_line="$2" preflight_mode="${3:-safe}"
+
+  printf '%s\n' '# synthetic skill' '```bash' >"$path"
+  case "$preflight_mode" in
+    safe)
+      printf '%s\n' \
+        'device_serial="${ANDROID_SERIAL-}"' \
+        'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
+        '  exit 2' \
+        'fi' >>"$path"
+      ;;
+    duplicate)
+      printf '%s\n' \
+        'device_serial="${ANDROID_SERIAL-}"' \
+        'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
+        '  exit 2' \
+        'fi' \
+        'device_serial="${ANDROID_SERIAL-}"' \
+        'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
+        '  exit 2' \
+        'fi' >>"$path"
+      ;;
+    same-line)
+      printf '%s\n' \
+        'device_serial="${ANDROID_SERIAL-}"; device_serial="${ANDROID_SERIAL-}"' \
+        'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
+        '  exit 2' \
+        'fi' >>"$path"
+      ;;
+    comment)
+      printf '%s\n' \
+        '# device_serial="${ANDROID_SERIAL-}"' \
+        '# if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' >>"$path"
+      ;;
+    reassignment)
+      printf '%s\n' \
+        'device_serial="${ANDROID_SERIAL-}"' \
+        'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
+        '  exit 2' \
+        'fi' \
+        'device_serial="$other_serial"' >>"$path"
+      ;;
+    *)
+      return 2
+      ;;
+  esac
   printf '%s\n' "$adb_line" '```' >>"$path"
 }
 
 device_safety_expect_synthetic_skill_rejection() {
   local case_name="$1" path="$2" failures_before rc
 
   failures_before="$DEVICE_SAFETY_FAILURES"
   device_safety_check_skill_file "synthetic-$case_name" "$path"
   rc=$?
   [[ "$rc" -ne 0 && "$DEVICE_SAFETY_FAILURES" -gt "$failures_before" ]] ||
     device_safety_fail "synthetic $case_name: unsafe ADB contract must be rejected"
   DEVICE_SAFETY_FAILURES="$failures_before"
 }
 
 device_safety_run_skill_contract_selftest() {
   local fixture_dir safe_path chained_path devices_path other_serial_path duplicate_path
+  local zero_arg_path operator_path same_line_path comment_path reassignment_path
 
   fixture_dir="$DEVICE_SAFETY_TMPDIR/skill-contract-selftest"
   mkdir -p "$fixture_dir"
   safe_path="$fixture_dir/safe.md"
   chained_path="$fixture_dir/chained.md"
   devices_path="$fixture_dir/devices.md"
   other_serial_path="$fixture_dir/other-serial.md"
   duplicate_path="$fixture_dir/duplicate.md"
+  zero_arg_path="$fixture_dir/zero-arg.md"
+  operator_path="$fixture_dir/operator.md"
+  same_line_path="$fixture_dir/same-line.md"
+  comment_path="$fixture_dir/comment.md"
+  reassignment_path="$fixture_dir/reassignment.md"
 
   device_safety_write_synthetic_skill "$safe_path" 'adb -s "$device_serial" root'
   device_safety_check_skill_file synthetic-safe "$safe_path" ||
     device_safety_fail 'synthetic safe: expected contract acceptance'
 
   device_safety_write_synthetic_skill "$chained_path" \
     'adb -s "$device_serial" root && adb reboot'
   device_safety_expect_synthetic_skill_rejection chained "$chained_path"
 
   device_safety_write_synthetic_skill "$devices_path" \
     $'adb -s "$device_serial" root\nadb devices'
   device_safety_expect_synthetic_skill_rejection devices "$devices_path"
 
   device_safety_write_synthetic_skill "$other_serial_path" \
     $'adb -s "$device_serial" root\nadb -s "$other_serial" wait-for-device'
   device_safety_expect_synthetic_skill_rejection other-serial "$other_serial_path"
 
   device_safety_write_synthetic_skill "$duplicate_path" \
-    'adb -s "$device_serial" root' 1
+    'adb -s "$device_serial" root' duplicate
   device_safety_expect_synthetic_skill_rejection duplicate-preflight "$duplicate_path"
+
+  device_safety_write_synthetic_skill "$zero_arg_path" \
+    'adb -s "$device_serial" root; adb;' safe
+  device_safety_expect_synthetic_skill_rejection zero-arg "$zero_arg_path"
+
+  device_safety_write_synthetic_skill "$operator_path" \
+    'adb -s "$device_serial" root && adb&&' safe
+  device_safety_expect_synthetic_skill_rejection operator-adb "$operator_path"
+
+  device_safety_write_synthetic_skill "$same_line_path" \
+    'adb -s "$device_serial" root' same-line
+  device_safety_expect_synthetic_skill_rejection same-line-preflight "$same_line_path"
+
+  device_safety_write_synthetic_skill "$comment_path" \
+    'adb -s "$device_serial" root' comment
+  device_safety_expect_synthetic_skill_rejection comment-preflight "$comment_path"
+
+  device_safety_write_synthetic_skill "$reassignment_path" \
+    'adb -s "$device_serial" root' reassignment
+  device_safety_expect_synthetic_skill_rejection reassignment "$reassignment_path"
 }
 
 main() {
   local scope
 
   if [[ "$#" -ne 0 ]]; then
     printf 'error: test-device-safety.sh accepts no positional arguments\n' >&2
     return 2
   fi
 
```
