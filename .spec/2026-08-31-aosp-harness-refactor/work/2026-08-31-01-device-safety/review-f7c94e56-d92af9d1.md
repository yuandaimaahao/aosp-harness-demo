# review 包 f7c94e56..d92af9d1

## commit 列表

```
d92af9d test: isolate skill mutation oracle probes
```

## diff --stat

```
 tests/test-device-safety.sh | 135 ++++++++++++++++++++++++--------------------
 1 file changed, 73 insertions(+), 62 deletions(-)
```

## diff

```diff
diff --git a/tests/test-device-safety.sh b/tests/test-device-safety.sh
index a78794d..fb57e03 100755
--- a/tests/test-device-safety.sh
+++ b/tests/test-device-safety.sh
@@ -417,111 +417,105 @@ device_safety_check_skill_file() {
 
 device_safety_run_skill_contract() {
   device_safety_check_skill_file \
     build-services-jar ./claude-code/features/.harness/skills/build-services-jar/SKILL.md
   device_safety_check_skill_file \
     build-sepolicy ./claude-code/features/.harness/skills/build-sepolicy/SKILL.md
 }
 
 device_safety_mutate_skill_file() {
   local source_path="$1" mutated_path="$2" mutation_kind="$3"
-  local count_path="$mutated_path.replacements" replacement_count
+  local blocks_dir="$mutated_path.blocks" source_block baseline_path
+  local mutated_block="$mutated_path.block" count_path="$mutated_path.replacements"
+  local extracted_count replacement_count
   local regex_line unsafe_regex fixed_prefix bare_prefix
 
   regex_line='if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then'
   unsafe_regex='if [[ -z "$device_serial" ]]; then'
   fixed_prefix='adb -s "$device_serial" '
   bare_prefix='adb '
 
+  extracted_count="$(device_safety_extract_device_blocks mutation-source "$source_path" "$blocks_dir")" || return 1
+  [[ "$extracted_count" == 1 ]] || return 1
+  source_block="$blocks_dir/block-1.bash"
+  baseline_path="$mutated_path.baseline"
+  {
+    printf '%s\n' '# temporary mutation skill' '```bash'
+    awk '{ print }' "$source_block"
+    printf '%s\n' '```'
+  } >"$baseline_path"
+
   awk \
     -v mutation_kind="$mutation_kind" \
     -v regex_line="$regex_line" \
     -v unsafe_regex="$unsafe_regex" \
     -v fixed_prefix="$fixed_prefix" \
     -v bare_prefix="$bare_prefix" \
     -v count_path="$count_path" '
-      function emit_block(    i, target, changed, line) {
-        target = 0
-        for (i = 1; i <= block_count; i++) {
-          if (block[i] ~ /(^|[;&][[:space:]]*)adb[[:space:]].*(root|remount|push|reboot|shell)/) {
-            target = 1
-          }
+      {
+        line = $0
+        if (replacement_count == 0 && mutation_kind == "regex" && line == regex_line) {
+          line = unsafe_regex
+          replacement_count++
         }
-        for (i = 1; i <= block_count; i++) {
-          line = block[i]
-          if (target && replacement_count == 0 && mutation_kind == "regex" && line == regex_line) {
-            line = unsafe_regex
-            replacement_count++
-          }
-          if (target && replacement_count == 0 && mutation_kind == "bare" && index(line, fixed_prefix) > 0) {
-            prefix_at = index(line, fixed_prefix)
-            line = substr(line, 1, prefix_at - 1) bare_prefix substr(line, prefix_at + length(fixed_prefix))
-            replacement_count++
-          }
-          print line
+        if (replacement_count == 0 && mutation_kind == "bare" &&
+          line ~ /^[[:space:]]*adb -s "\$device_serial" /) {
+          prefix_at = index(line, fixed_prefix)
+          line = substr(line, 1, prefix_at - 1) bare_prefix substr(line, prefix_at + length(fixed_prefix))
+          replacement_count++
         }
-        delete block
-        block_count = 0
-      }
-      /^```bash[[:space:]]*$/ && !in_bash {
-        in_bash = 1
-        block_count = 0
-        print
-        next
-      }
-      /^```[[:space:]]*$/ && in_bash {
-        emit_block()
-        in_bash = 0
-        print
-        next
+        print line
       }
-      in_bash {
-        block[++block_count] = $0
-        next
-      }
-      { print }
       END {
-        if (in_bash) emit_block()
         print replacement_count > count_path
       }
-    ' "$source_path" >"$mutated_path" || return 1
+    ' "$source_block" >"$mutated_block" || return 1
 
   replacement_count="$(<"$count_path")"
   [[ "$replacement_count" == 1 ]] || return 1
-  ! cmp -s "$source_path" "$mutated_path"
+  {
+    printf '%s\n' '# temporary mutation skill' '```bash'
+    awk '{ print }' "$mutated_block"
+    printf '%s\n' '```'
+  } >"$mutated_path"
+  ! cmp -s "$baseline_path" "$mutated_path"
 }
 
 device_safety_expect_skill_mutation_rejection() {
   local skill_name="$1" source_path="$2" mutation_kind="$3" expected_error="$4"
-  local mutated_path stderr_path failures_before rc
+  local checker_function="${5:-device_safety_check_skill_file}"
+  local mutated_path stderr_path rejected=0 failed=0
 
   mutated_path="$DEVICE_SAFETY_TMPDIR/skill-mutations/$skill_name-$mutation_kind.md"
   stderr_path="$mutated_path.stderr"
   mkdir -p "${mutated_path%/*}"
   device_safety_mutate_skill_file "$source_path" "$mutated_path" "$mutation_kind" || {
     device_safety_fail "$skill_name $mutation_kind mutation: expected exactly one changed target-block line"
     return
   }
-  cmp -s "$source_path" "$mutated_path" && {
-    device_safety_fail "$skill_name $mutation_kind mutation: expected temporary copy to change"
-    return
-  }
-
-  failures_before="$DEVICE_SAFETY_FAILURES"
-  device_safety_check_skill_file "$skill_name-$mutation_kind" "$mutated_path" 2>"$stderr_path"
-  rc=$?
-  [[ "$rc" -ne 0 && "$DEVICE_SAFETY_FAILURES" -gt "$failures_before" &&
-    -s "$stderr_path" ]] ||
+  if (
+    DEVICE_SAFETY_FAILURES=0
+    "$checker_function" "$skill_name-$mutation_kind" "$mutated_path" 2>"$stderr_path"
+    checker_rc=$?
+    [[ "$checker_rc" -ne 0 && "$DEVICE_SAFETY_FAILURES" -gt 0 ]]
+  ); then
+    rejected=1
+  fi
+  if [[ "$rejected" -ne 1 ]]; then
     device_safety_fail "$skill_name $mutation_kind mutation: unsafe skill must be rejected"
-  grep -Fq "FAIL  $skill_name-$mutation_kind device block 1: $expected_error" "$stderr_path" ||
+    failed=1
+  fi
+  if ! grep -Fq "FAIL  $skill_name-$mutation_kind device block 1: $expected_error" "$stderr_path"; then
     device_safety_fail "$skill_name $mutation_kind mutation: expected $expected_error"
-  DEVICE_SAFETY_FAILURES="$failures_before"
+    failed=1
+  fi
+  return "$failed"
 }
 
 device_safety_run_skill_mutations() {
   local skill_name skill_path
   local skill_names=(build-services-jar build-sepolicy)
   local skill_paths=(
     ./claude-code/features/.harness/skills/build-services-jar/SKILL.md
     ./claude-code/features/.harness/skills/build-sepolicy/SKILL.md
   )
   local index
@@ -530,33 +524,48 @@ device_safety_run_skill_mutations() {
     skill_name="${skill_names[$index]}"
     skill_path="${skill_paths[$index]}"
     device_safety_expect_skill_mutation_rejection \
       "$skill_name" "$skill_path" regex 'missing safe serial preflight'
     device_safety_expect_skill_mutation_rejection \
       "$skill_name" "$skill_path" bare 'bare adb'
   done
 }
 
 device_safety_run_skill_mutation_selftest() {
-  local fixture_dir regex_path bare_path
+  local fixture_dir regex_path bare_path accepted_path
 
   fixture_dir="$DEVICE_SAFETY_TMPDIR/skill-mutation-selftest"
   mkdir -p "$fixture_dir"
   regex_path="$fixture_dir/regex-safe.md"
   bare_path="$fixture_dir/bare-safe.md"
+  accepted_path="$fixture_dir/accepted-safe.md"
   device_safety_write_synthetic_skill "$regex_path" 'adb -s "$device_serial" root'
   device_safety_write_synthetic_skill "$bare_path" 'adb -s "$device_serial" shell service list'
 
   device_safety_expect_skill_mutation_rejection \
     synthetic-regex "$regex_path" regex 'missing safe serial preflight'
   device_safety_expect_skill_mutation_rejection \
     synthetic-bare "$bare_path" bare 'bare adb'
+  device_safety_write_synthetic_skill "$accepted_path" 'adb -s "$device_serial" root'
+  if ! (
+    DEVICE_SAFETY_FAILURES=0
+    device_safety_expect_skill_mutation_rejection \
+      synthetic-accepted "$accepted_path" regex 'missing safe serial preflight' \
+      device_safety_accept_unsafe_checker 2>/dev/null
+    [[ "$DEVICE_SAFETY_FAILURES" -gt 0 ]]
+  ); then
+    device_safety_fail 'synthetic accepted mutation: outer assertion must retain failure'
+  fi
+}
+
+device_safety_accept_unsafe_checker() {
+  return 0
 }
 
 device_safety_run_skills() {
   device_safety_run_skill_contract
   [[ "$DEVICE_SAFETY_FAILURES" -eq 0 ]] || return
   device_safety_run_skill_mutations
 }
 
 device_safety_write_synthetic_skill() {
   local path="$1" adb_line="$2" preflight_mode="${3:-safe}"
@@ -610,28 +619,30 @@ device_safety_write_synthetic_skill() {
         'device_serial+=-other' >>"$path"
       ;;
     *)
       return 2
       ;;
   esac
   printf '%s\n' "$adb_line" '```' >>"$path"
 }
 
 device_safety_expect_synthetic_skill_rejection() {
-  local case_name="$1" path="$2" failures_before rc
-
-  failures_before="$DEVICE_SAFETY_FAILURES"
-  device_safety_check_skill_file "synthetic-$case_name" "$path"
-  rc=$?
-  [[ "$rc" -ne 0 && "$DEVICE_SAFETY_FAILURES" -gt "$failures_before" ]] ||
+  local case_name="$1" path="$2"
+
+  if ! (
+    DEVICE_SAFETY_FAILURES=0
+    device_safety_check_skill_file "synthetic-$case_name" "$path"
+    checker_rc=$?
+    [[ "$checker_rc" -ne 0 && "$DEVICE_SAFETY_FAILURES" -gt 0 ]]
+  ); then
     device_safety_fail "synthetic $case_name: unsafe ADB contract must be rejected"
-  DEVICE_SAFETY_FAILURES="$failures_before"
+  fi
 }
 
 device_safety_run_skill_contract_selftest() {
   local fixture_dir safe_path chained_path devices_path other_serial_path duplicate_path
   local zero_arg_path operator_path same_line_path comment_path reassignment_path
   local redirect_path append_path
 
   fixture_dir="$DEVICE_SAFETY_TMPDIR/skill-contract-selftest"
   mkdir -p "$fixture_dir"
   safe_path="$fixture_dir/safe.md"
```
