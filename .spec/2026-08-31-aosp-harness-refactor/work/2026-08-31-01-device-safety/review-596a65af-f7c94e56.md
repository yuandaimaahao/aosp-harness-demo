# review 包 596a65af..f7c94e56

## commit 列表

```
f7c94e5 test: prove skill contract oracle mutations
```

## diff --stat

```
 tests/test-device-safety.sh | 144 +++++++++++++++++++++++++++++++++++++++++++-
 1 file changed, 142 insertions(+), 2 deletions(-)
```

## diff

```diff
diff --git a/tests/test-device-safety.sh b/tests/test-device-safety.sh
index 45de233..a78794d 100755
--- a/tests/test-device-safety.sh
+++ b/tests/test-device-safety.sh
@@ -331,21 +331,21 @@ device_safety_run_skill_blocks() {
       continue
     }
     [[ "$extracted_count" == 1 ]] ||
       device_safety_fail "$skill_name: expected exactly one fenced device block"
   done
 }
 
 device_safety_check_skill_file() {
   local skill_name="$1" path="$2" blocks_dir extracted_count block
   local serial_line regex_line first_adb serial_at regex_at serial_count regex_count
-  local expected_prefix adb_word_pattern line trimmed adb_remainder line_number=0
+  local expected_prefix unsafe_regex_line adb_word_pattern line trimmed adb_remainder line_number=0
   local adb_count adb_contract_valid serial_init_line regex_guard_line
 
   blocks_dir="$DEVICE_SAFETY_TMPDIR/skill-contract-$skill_name"
   extracted_count="$(device_safety_extract_device_blocks "$skill_name" "$path" "$blocks_dir")" || {
     device_safety_fail "$skill_name: failed to extract fenced device blocks"
     return 1
   }
   [[ "$extracted_count" == 1 ]] || {
     device_safety_fail "$skill_name: expected exactly one fenced device block"
     return 1
@@ -355,20 +355,21 @@ device_safety_check_skill_file() {
   serial_line='device_serial="${ANDROID_SERIAL-}"'
   regex_line='if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then'
   first_adb=''
   serial_at=''
   regex_at=''
   serial_count=0
   regex_count=0
   adb_count=0
   adb_contract_valid=1
   expected_prefix='adb -s "$device_serial" '
+  unsafe_regex_line='if [[ -z "$device_serial" ]]; then'
   adb_word_pattern='(^|[^[:alnum:]_])adb([^[:alnum:]_]|$)'
   while IFS= read -r line || [[ -n "$line" ]]; do
     line_number=$((line_number + 1))
     trimmed="${line#"${line%%[![:space:]]*}"}"
     trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
     [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue
 
     serial_init_line=0
     regex_guard_line=0
     if [[ "$trimmed" == "$serial_line" ]]; then
@@ -376,21 +377,22 @@ device_safety_check_skill_file() {
       serial_count=$((serial_count + 1))
       serial_at="$line_number"
     fi
     if [[ "$trimmed" == "$regex_line" ]]; then
       regex_guard_line=1
       regex_count=$((regex_count + 1))
       regex_at="$line_number"
     fi
 
     if [[ "$trimmed" == *device_serial* && "$serial_init_line" -eq 0 &&
-      "$regex_guard_line" -eq 0 && "$trimmed" != "$expected_prefix"* ]]; then
+      "$regex_guard_line" -eq 0 && "$trimmed" != "$unsafe_regex_line" &&
+      "$trimmed" != "$expected_prefix"* ]]; then
       device_safety_fail "$skill_name device block 1: device_serial reference not allowed"
       return 1
     fi
 
     if [[ "$trimmed" =~ $adb_word_pattern ]]; then
       [[ -n "$first_adb" ]] || first_adb="$line_number"
       adb_count=$((adb_count + 1))
       if [[ "$trimmed" != "$expected_prefix"* ]]; then
         adb_contract_valid=0
       else
@@ -413,20 +415,156 @@ device_safety_check_skill_file() {
   }
 }
 
 device_safety_run_skill_contract() {
   device_safety_check_skill_file \
     build-services-jar ./claude-code/features/.harness/skills/build-services-jar/SKILL.md
   device_safety_check_skill_file \
     build-sepolicy ./claude-code/features/.harness/skills/build-sepolicy/SKILL.md
 }
 
+device_safety_mutate_skill_file() {
+  local source_path="$1" mutated_path="$2" mutation_kind="$3"
+  local count_path="$mutated_path.replacements" replacement_count
+  local regex_line unsafe_regex fixed_prefix bare_prefix
+
+  regex_line='if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then'
+  unsafe_regex='if [[ -z "$device_serial" ]]; then'
+  fixed_prefix='adb -s "$device_serial" '
+  bare_prefix='adb '
+
+  awk \
+    -v mutation_kind="$mutation_kind" \
+    -v regex_line="$regex_line" \
+    -v unsafe_regex="$unsafe_regex" \
+    -v fixed_prefix="$fixed_prefix" \
+    -v bare_prefix="$bare_prefix" \
+    -v count_path="$count_path" '
+      function emit_block(    i, target, changed, line) {
+        target = 0
+        for (i = 1; i <= block_count; i++) {
+          if (block[i] ~ /(^|[;&][[:space:]]*)adb[[:space:]].*(root|remount|push|reboot|shell)/) {
+            target = 1
+          }
+        }
+        for (i = 1; i <= block_count; i++) {
+          line = block[i]
+          if (target && replacement_count == 0 && mutation_kind == "regex" && line == regex_line) {
+            line = unsafe_regex
+            replacement_count++
+          }
+          if (target && replacement_count == 0 && mutation_kind == "bare" && index(line, fixed_prefix) > 0) {
+            prefix_at = index(line, fixed_prefix)
+            line = substr(line, 1, prefix_at - 1) bare_prefix substr(line, prefix_at + length(fixed_prefix))
+            replacement_count++
+          }
+          print line
+        }
+        delete block
+        block_count = 0
+      }
+      /^```bash[[:space:]]*$/ && !in_bash {
+        in_bash = 1
+        block_count = 0
+        print
+        next
+      }
+      /^```[[:space:]]*$/ && in_bash {
+        emit_block()
+        in_bash = 0
+        print
+        next
+      }
+      in_bash {
+        block[++block_count] = $0
+        next
+      }
+      { print }
+      END {
+        if (in_bash) emit_block()
+        print replacement_count > count_path
+      }
+    ' "$source_path" >"$mutated_path" || return 1
+
+  replacement_count="$(<"$count_path")"
+  [[ "$replacement_count" == 1 ]] || return 1
+  ! cmp -s "$source_path" "$mutated_path"
+}
+
+device_safety_expect_skill_mutation_rejection() {
+  local skill_name="$1" source_path="$2" mutation_kind="$3" expected_error="$4"
+  local mutated_path stderr_path failures_before rc
+
+  mutated_path="$DEVICE_SAFETY_TMPDIR/skill-mutations/$skill_name-$mutation_kind.md"
+  stderr_path="$mutated_path.stderr"
+  mkdir -p "${mutated_path%/*}"
+  device_safety_mutate_skill_file "$source_path" "$mutated_path" "$mutation_kind" || {
+    device_safety_fail "$skill_name $mutation_kind mutation: expected exactly one changed target-block line"
+    return
+  }
+  cmp -s "$source_path" "$mutated_path" && {
+    device_safety_fail "$skill_name $mutation_kind mutation: expected temporary copy to change"
+    return
+  }
+
+  failures_before="$DEVICE_SAFETY_FAILURES"
+  device_safety_check_skill_file "$skill_name-$mutation_kind" "$mutated_path" 2>"$stderr_path"
+  rc=$?
+  [[ "$rc" -ne 0 && "$DEVICE_SAFETY_FAILURES" -gt "$failures_before" &&
+    -s "$stderr_path" ]] ||
+    device_safety_fail "$skill_name $mutation_kind mutation: unsafe skill must be rejected"
+  grep -Fq "FAIL  $skill_name-$mutation_kind device block 1: $expected_error" "$stderr_path" ||
+    device_safety_fail "$skill_name $mutation_kind mutation: expected $expected_error"
+  DEVICE_SAFETY_FAILURES="$failures_before"
+}
+
+device_safety_run_skill_mutations() {
+  local skill_name skill_path
+  local skill_names=(build-services-jar build-sepolicy)
+  local skill_paths=(
+    ./claude-code/features/.harness/skills/build-services-jar/SKILL.md
+    ./claude-code/features/.harness/skills/build-sepolicy/SKILL.md
+  )
+  local index
+
+  for ((index=0; index<${#skill_names[@]}; index++)); do
+    skill_name="${skill_names[$index]}"
+    skill_path="${skill_paths[$index]}"
+    device_safety_expect_skill_mutation_rejection \
+      "$skill_name" "$skill_path" regex 'missing safe serial preflight'
+    device_safety_expect_skill_mutation_rejection \
+      "$skill_name" "$skill_path" bare 'bare adb'
+  done
+}
+
+device_safety_run_skill_mutation_selftest() {
+  local fixture_dir regex_path bare_path
+
+  fixture_dir="$DEVICE_SAFETY_TMPDIR/skill-mutation-selftest"
+  mkdir -p "$fixture_dir"
+  regex_path="$fixture_dir/regex-safe.md"
+  bare_path="$fixture_dir/bare-safe.md"
+  device_safety_write_synthetic_skill "$regex_path" 'adb -s "$device_serial" root'
+  device_safety_write_synthetic_skill "$bare_path" 'adb -s "$device_serial" shell service list'
+
+  device_safety_expect_skill_mutation_rejection \
+    synthetic-regex "$regex_path" regex 'missing safe serial preflight'
+  device_safety_expect_skill_mutation_rejection \
+    synthetic-bare "$bare_path" bare 'bare adb'
+}
+
+device_safety_run_skills() {
+  device_safety_run_skill_contract
+  [[ "$DEVICE_SAFETY_FAILURES" -eq 0 ]] || return
+  device_safety_run_skill_mutations
+}
+
 device_safety_write_synthetic_skill() {
   local path="$1" adb_line="$2" preflight_mode="${3:-safe}"
 
   printf '%s\n' '# synthetic skill' '```bash' >"$path"
   case "$preflight_mode" in
     safe)
       printf '%s\n' \
         'device_serial="${ANDROID_SERIAL-}"' \
         'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
         '  exit 2' \
@@ -576,11 +714,13 @@ main() {
 
 device_safety_register_scope fixture device_safety_run_fixture
 device_safety_register_scope claude-invalid-serial device_safety_run_claude_invalid_serial_matrix
 device_safety_register_scope claude-valid-serial device_safety_run_claude_valid_serial_matrix
 device_safety_register_scope claude-flag-demo device_safety_run_claude_flag_demo_matrix
 device_safety_register_scope codex-flag-demo device_safety_run_codex_flag_demo_matrix
 device_safety_register_scope flag-demo device_safety_run_flag_and_demo_matrix
 device_safety_register_scope skill-blocks device_safety_run_skill_blocks
 device_safety_register_scope skill-contract device_safety_run_skill_contract
 device_safety_register_scope skill-contract-selftest device_safety_run_skill_contract_selftest
+device_safety_register_scope mutation-selftest device_safety_run_skill_mutation_selftest
+device_safety_register_scope skills device_safety_run_skills
 main "$@"
```
