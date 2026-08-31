#!/usr/bin/env bash
set -u

DEVICE_SAFETY_SCOPE_NAMES=()
DEVICE_SAFETY_SCOPE_FUNCS=()
DEVICE_SAFETY_FAILURES=0
DEVICE_SAFETY_TMPDIR=''

device_safety_fail() {
  printf 'FAIL  %s\n' "$*" >&2
  DEVICE_SAFETY_FAILURES=$((DEVICE_SAFETY_FAILURES + 1))
}

device_safety_register_scope() {
  DEVICE_SAFETY_SCOPE_NAMES+=("$1")
  DEVICE_SAFETY_SCOPE_FUNCS+=("$2")
}

device_safety_run_scope() {
  local wanted="$1" i
  for ((i=0; i<${#DEVICE_SAFETY_SCOPE_NAMES[@]}; i++)); do
    [[ "${DEVICE_SAFETY_SCOPE_NAMES[$i]}" != "$wanted" ]] || {
      "${DEVICE_SAFETY_SCOPE_FUNCS[$i]}"
      return
    }
  done
  printf 'error: unknown DEVICE_SAFETY_TEST_SCOPE: %s\n' "$wanted" >&2
  return 2
}

device_safety_cleanup() {
  [[ -z "$DEVICE_SAFETY_TMPDIR" ]] || rm -rf "$DEVICE_SAFETY_TMPDIR"
}

device_safety_fake_adb_install() {
  local fixture="$1" serial="$2"
  local fixture_dir="$DEVICE_SAFETY_TMPDIR/$fixture"

  mkdir -p "$fixture_dir/bin"
  ADB_LOG="$fixture_dir/adb.log"
  EXPECTED_SERIAL="$serial"
  export ADB_LOG EXPECTED_SERIAL
  : >"$ADB_LOG"
  cat >"$fixture_dir/bin/adb" <<'EOF'
#!/usr/bin/env bash
printf 'adb ' >>"$ADB_LOG"
printf '%q ' "$@" >>"$ADB_LOG"
printf '\n' >>"$ADB_LOG"
[[ "${1-}" == -s && "${2-}" == "$EXPECTED_SERIAL" ]] || exit 91
shift 2
case "$*" in
  'shell getprop sys.boot_completed') printf '1\n' ;;
  'shell pidof system_server') printf '1423\n' ;;
  'shell cat /proc/stat') printf 'btime 200\n' ;;
  logcat\ -b\ crash\ -d\ -v\ *\ -T\ *) exit 0 ;;
  'shell service list') printf '52 sidebar: [android.sidebar.ISidebar]\n' ;;
  'shell pm list packages') printf 'package:com.android.sidebar\n' ;;
  *) exit 92 ;;
esac
EOF
  chmod +x "$fixture_dir/bin/adb"
  DEVICE_SAFETY_FAKE_BIN="$fixture_dir/bin"
  export DEVICE_SAFETY_FAKE_BIN
}

device_safety_run_fixture() {
  local output rc fake_adb

  device_safety_fake_adb_install fixture demo-serial
  fake_adb="$DEVICE_SAFETY_FAKE_BIN/adb"
  [[ "$(PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" command -v adb)" == "$fake_adb" ]] ||
    device_safety_fail 'fixture: private fake adb bin must be first in PATH'
  trap -p EXIT | grep -Fq 'device_safety_cleanup' ||
    device_safety_fail 'fixture: cleanup trap must be registered'

  output="$(PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" adb -s demo-serial shell getprop sys.boot_completed)" ||
    device_safety_fail 'fixture: expected shell response to succeed'
  [[ "$output" == 1 ]] || device_safety_fail 'fixture: unexpected shell response'

  output="$(PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" adb -s demo-serial shell pidof system_server)" ||
    device_safety_fail 'fixture: expected pidof response to succeed'
  [[ "$output" == 1423 ]] || device_safety_fail 'fixture: unexpected pidof response'

  output="$(PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" adb -s demo-serial shell cat /proc/stat)" ||
    device_safety_fail 'fixture: expected proc stat response to succeed'
  [[ "$output" == 'btime 200' ]] || device_safety_fail 'fixture: unexpected proc stat response'

  PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" adb -s demo-serial logcat -b crash -d -v threadtime -T 200 >/dev/null ||
    device_safety_fail 'fixture: expected logcat response to succeed'

  output="$(PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" adb -s demo-serial shell service list)" ||
    device_safety_fail 'fixture: expected service list response to succeed'
  [[ "$output" == '52 sidebar: [android.sidebar.ISidebar]' ]] ||
    device_safety_fail 'fixture: unexpected service list response'

  output="$(PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" adb -s demo-serial shell pm list packages)" ||
    device_safety_fail 'fixture: expected package list response to succeed'
  [[ "$output" == package:com.android.sidebar ]] ||
    device_safety_fail 'fixture: unexpected package list response'

  PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" adb -s other-serial shell getprop sys.boot_completed >/dev/null 2>&1
  rc=$?
  [[ "$rc" -eq 91 ]] || device_safety_fail 'fixture: unknown serial must exit 91'

  PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" adb -s demo-serial unknown command >/dev/null 2>&1
  rc=$?
  [[ "$rc" -eq 92 ]] || device_safety_fail 'fixture: unknown command must exit 92'

  [[ -s "$ADB_LOG" ]] || device_safety_fail 'fixture: fake adb log must be non-empty'
  grep -Fq 'adb -s demo-serial shell getprop sys.boot_completed ' "$ADB_LOG" ||
    device_safety_fail 'fixture: adb log must include command name'
  grep -Fq 'adb -s demo-serial logcat -b crash -d -v threadtime -T 200 ' "$ADB_LOG" ||
    device_safety_fail 'fixture: adb log must include logcat command name'
  grep -Fq 'adb -s other-serial shell getprop sys.boot_completed ' "$ADB_LOG" ||
    device_safety_fail 'fixture: adb log must include rejected serial command'
  grep -Fq 'adb -s demo-serial unknown command ' "$ADB_LOG" ||
    device_safety_fail 'fixture: adb log must include rejected unknown command'
}

device_safety_run_claude_invalid_serial_matrix() {
  local invalid_serials serial case_name fixture_dir stderr_file stdout_file adb_log label rc
  local case_index=0

  invalid_serials=(
    '__UNSET__' '-bad' '.bad' '_bad' ':bad' 'bad/path' 'bad value'
    $'bad\nvalue' 'bad;value' 'bad+value'
  )

  for serial in "${invalid_serials[@]}"; do
    case_index=$((case_index + 1))
    case_name="$serial"
    [[ "$serial" != '__UNSET__' ]] || case_name='missing'
    label="claude $case_name ANDROID_SERIAL"

    device_safety_fake_adb_install "claude-invalid-$case_index" demo-serial
    fixture_dir="$DEVICE_SAFETY_TMPDIR/claude-invalid-$case_index"
    stderr_file="$fixture_dir/stderr"
    stdout_file="$fixture_dir/stdout"
    adb_log="$ADB_LOG"

    if [[ "$serial" == '__UNSET__' ]]; then
      env -u ANDROID_SERIAL PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" \
        bash ./claude-code/features/dev-sidebar/verify-sidebar.sh \
        >"$stdout_file" 2>"$stderr_file"
    else
      ANDROID_SERIAL="$serial" PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" \
        bash ./claude-code/features/dev-sidebar/verify-sidebar.sh \
        >"$stdout_file" 2>"$stderr_file"
    fi
    rc=$?

    [[ "$rc" -eq 2 ]] || device_safety_fail "$label: expected rc=2 and zero adb calls"
    grep -Fq 'ANDROID_SERIAL' "$stderr_file" ||
      device_safety_fail "$label: missing ANDROID_SERIAL error"
    [[ ! -s "$adb_log" ]] || device_safety_fail "$label: expected zero adb calls"
  done
}

device_safety_run_claude_valid_serial_matrix() {
  local valid_serials serial fixture_dir stderr_file stdout_file adb_log expected_prefix rc
  local case_index=0

  valid_serials=('demo-serial' 'A0._:-z')

  for serial in "${valid_serials[@]}"; do
    case_index=$((case_index + 1))
    device_safety_fake_adb_install "claude-valid-$case_index" "$serial"
    fixture_dir="$DEVICE_SAFETY_TMPDIR/claude-valid-$case_index"
    stderr_file="$fixture_dir/stderr"
    stdout_file="$fixture_dir/stdout"
    adb_log="$ADB_LOG"
    expected_prefix="adb -s $serial "

    ANDROID_SERIAL="$serial" PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" \
      bash ./claude-code/features/dev-sidebar/verify-sidebar.sh --since 200 \
      >"$stdout_file" 2>"$stderr_file"
    rc=$?

    [[ -s "$adb_log" ]] ||
      device_safety_fail "claude $serial: expected non-empty adb log"
    awk -v prefix="$expected_prefix" 'index($0, prefix) != 1 { exit 1 }' "$adb_log" ||
      device_safety_fail "claude $serial: expected adb -s prefix on every call"
    [[ "$rc" -eq 0 && "$(tail -n 1 "$stdout_file")" == 'RESULT PASS' ]] ||
      device_safety_fail "claude $serial: expected rc=0 and RESULT PASS"
  done
}

device_safety_run_flag_and_demo_for() {
  local verifier_name="$1" verifier_path="$2" entry case_verifier serial fixture_dir stderr_file stdout_file adb_log rc
  local flag_cases=(
    'claude|__UNSET__' 'claude|-bad'
    'codex|__UNSET__' 'codex|-bad'
  )
  local expected_error='--allow-skip requires --demo'

  [[ -x "$verifier_path" ]] || {
    device_safety_fail "$verifier_name flag-demo: verifier must be executable"
    return
  }

  for entry in "${flag_cases[@]}"; do
    IFS='|' read -r case_verifier serial <<<"$entry"
    [[ "$case_verifier" == "$verifier_name" ]] || continue
    if [[ "$serial" == '__UNSET__' ]]; then
      fixture_dir="$DEVICE_SAFETY_TMPDIR/$verifier_name-flag-missing"
      device_safety_fake_adb_install "$verifier_name-flag-missing" demo-serial
      stderr_file="$fixture_dir/stderr"
      stdout_file="$fixture_dir/stdout"
      adb_log="$ADB_LOG"
      env -u ANDROID_SERIAL PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" \
        bash "$verifier_path" --allow-skip >"$stdout_file" 2>"$stderr_file"
      rc=$?
      [[ "$rc" -eq 2 ]] && grep -Fq -- "$expected_error" "$stderr_file" &&
        ! grep -Fq 'ANDROID_SERIAL' "$stderr_file" && [[ ! -s "$adb_log" ]] ||
        device_safety_fail "$verifier_name real allow-skip missing serial: expected flag error before ANDROID_SERIAL"
    else
      fixture_dir="$DEVICE_SAFETY_TMPDIR/$verifier_name-flag-invalid"
      device_safety_fake_adb_install "$verifier_name-flag-invalid" demo-serial
      stderr_file="$fixture_dir/stderr"
      stdout_file="$fixture_dir/stdout"
      adb_log="$ADB_LOG"
      ANDROID_SERIAL="$serial" PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" \
        bash "$verifier_path" --allow-skip >"$stdout_file" 2>"$stderr_file"
      rc=$?
      [[ "$rc" -eq 2 ]] && grep -Fq -- "$expected_error" "$stderr_file" &&
        ! grep -Fq 'ANDROID_SERIAL' "$stderr_file" && [[ ! -s "$adb_log" ]] ||
        device_safety_fail "$verifier_name real allow-skip invalid serial: expected flag error before ANDROID_SERIAL"
    fi
  done

  device_safety_fake_adb_install "$verifier_name-demo-skip" demo-serial
  fixture_dir="$DEVICE_SAFETY_TMPDIR/$verifier_name-demo-skip"
  stderr_file="$fixture_dir/stderr"
  stdout_file="$fixture_dir/stdout"
  adb_log="$ADB_LOG"
  DEMO_APP_INSTALLED=0 PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" \
    bash "$verifier_path" --demo --allow-skip >"$stdout_file" 2>"$stderr_file"
  rc=$?

  [[ "$rc" -eq 0 ]] ||
    device_safety_fail "$verifier_name demo allow-skip: expected rc=0"
  grep -Eq '^SKIP  ' "$stdout_file" ||
    device_safety_fail "$verifier_name demo allow-skip: expected SKIP detail"
  [[ "$(tail -n 1 "$stdout_file")" == 'RESULT PASS (SKIP allowed)' ]] ||
    device_safety_fail "$verifier_name demo allow-skip: expected RESULT PASS (SKIP allowed)"
  [[ ! -s "$adb_log" ]] ||
    device_safety_fail "$verifier_name demo allow-skip: expected zero adb calls"
}

device_safety_run_claude_flag_demo_matrix() {
  device_safety_run_flag_and_demo_for \
    claude ./claude-code/features/dev-sidebar/verify-sidebar.sh
}

device_safety_run_codex_flag_demo_matrix() {
  device_safety_run_flag_and_demo_for \
    codex ./codex/features/dev-sidebar/verify-sidebar.sh
}

device_safety_run_flag_and_demo_matrix() {
  device_safety_run_claude_flag_demo_matrix
  device_safety_run_codex_flag_demo_matrix
}

device_safety_extract_device_blocks() {
  local skill_name="$1" path="$2" output_dir="$3"
  local in_bash=0 block='' line count=0

  mkdir -p "$output_dir" || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$in_bash" -eq 0 && "$line" == '```bash' ]]; then
      in_bash=1
      block=''
      continue
    fi
    if [[ "$in_bash" -eq 1 && "$line" == '```' ]]; then
      if grep -Eq '(^|[;&][[:space:]]*)adb[[:space:]].*(root|remount|push|reboot|shell)' <<<"$block"; then
        count=$((count + 1))
        printf '%s\n' "$block" >"$output_dir/block-$count.bash"
      fi
      in_bash=0
      continue
    fi
    [[ "$in_bash" -eq 0 ]] || block+="${block:+$'\n'}$line"
  done <"$path"

  printf '%s\n' "$count"
}

device_safety_run_skill_blocks() {
  local fixture_dir fixture_path fixture_blocks extracted_count
  local skill_name skill_path skill_blocks
  local skill_names=(build-services-jar build-sepolicy)
  local skill_paths=(
    ./claude-code/features/.harness/skills/build-services-jar/SKILL.md
    ./claude-code/features/.harness/skills/build-sepolicy/SKILL.md
  )
  local index

  fixture_dir="$DEVICE_SAFETY_TMPDIR/skill-blocks"
  fixture_path="$fixture_dir/synthetic.md"
  fixture_blocks="$fixture_dir/synthetic-blocks"
  mkdir -p "$fixture_dir"
  printf '%s\n' \
    '# synthetic skill' \
    '```bash' \
    'm services' \
    '```' \
    'inline `adb shell service list` is not a fenced block' \
    '```bash' \
    'adb root' \
    '```' >"$fixture_path"

  extracted_count="$(device_safety_extract_device_blocks synthetic "$fixture_path" "$fixture_blocks")" || {
    device_safety_fail 'synthetic: failed to extract fenced device blocks'
    return
  }
  [[ "$extracted_count" == 1 ]] ||
    device_safety_fail 'synthetic: expected exactly one fenced device block'
  grep -Fqx 'adb root' "$fixture_blocks/block-1.bash" ||
    device_safety_fail 'synthetic: expected extracted device block'
  ! grep -Fq 'm services' "$fixture_blocks/block-1.bash" ||
    device_safety_fail 'synthetic: build block must not be extracted'

  for ((index=0; index<${#skill_names[@]}; index++)); do
    skill_name="${skill_names[$index]}"
    skill_path="${skill_paths[$index]}"
    skill_blocks="$fixture_dir/$skill_name"
    extracted_count="$(device_safety_extract_device_blocks "$skill_name" "$skill_path" "$skill_blocks")" || {
      device_safety_fail "$skill_name: failed to extract fenced device blocks"
      continue
    }
    [[ "$extracted_count" == 1 ]] ||
      device_safety_fail "$skill_name: expected exactly one fenced device block"
  done
}

device_safety_check_skill_file() {
  local skill_name="$1" path="$2" blocks_dir extracted_count block
  local serial_line regex_line first_adb serial_at regex_at serial_count regex_count
  local expected_prefix unsafe_regex_line adb_word_pattern line trimmed adb_remainder line_number=0
  local adb_count adb_contract_valid serial_init_line regex_guard_line

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
  first_adb=''
  serial_at=''
  regex_at=''
  serial_count=0
  regex_count=0
  adb_count=0
  adb_contract_valid=1
  expected_prefix='adb -s "$device_serial" '
  unsafe_regex_line='if [[ -z "$device_serial" ]]; then'
  adb_word_pattern='(^|[^[:alnum:]_])adb([^[:alnum:]_]|$)'
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    trimmed="${line#"${line%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue

    serial_init_line=0
    regex_guard_line=0
    if [[ "$trimmed" == "$serial_line" ]]; then
      serial_init_line=1
      serial_count=$((serial_count + 1))
      serial_at="$line_number"
    fi
    if [[ "$trimmed" == "$regex_line" ]]; then
      regex_guard_line=1
      regex_count=$((regex_count + 1))
      regex_at="$line_number"
    fi

    if [[ "$trimmed" == *device_serial* && "$serial_init_line" -eq 0 &&
      "$regex_guard_line" -eq 0 && "$trimmed" != "$unsafe_regex_line" &&
      "$trimmed" != "$expected_prefix"* ]]; then
      device_safety_fail "$skill_name device block 1: device_serial reference not allowed"
      return 1
    fi

    if [[ "$trimmed" =~ $adb_word_pattern ]]; then
      [[ -n "$first_adb" ]] || first_adb="$line_number"
      adb_count=$((adb_count + 1))
      if [[ "$trimmed" != "$expected_prefix"* ]]; then
        adb_contract_valid=0
      else
        adb_remainder="${trimmed#adb}"
        [[ "$adb_remainder" =~ $adb_word_pattern ]] && adb_contract_valid=0
      fi
    fi
  done <"$block"

  if [[ "$serial_count" -ne 1 || "$regex_count" -ne 1 ||
    -z "$first_adb" || -z "$serial_at" || -z "$regex_at" ||
    "$serial_at" -ge "$first_adb" || "$regex_at" -ge "$first_adb" ]]; then
    device_safety_fail "$skill_name device block 1: missing safe serial preflight"
    return 1
  fi

  [[ "$adb_count" -gt 0 && "$adb_contract_valid" -eq 1 ]] || {
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

device_safety_mutate_skill_file() {
  local source_path="$1" mutated_path="$2" mutation_kind="$3"
  local blocks_dir="$mutated_path.blocks" source_block baseline_path
  local mutated_block="$mutated_path.block" count_path="$mutated_path.replacements"
  local extracted_count replacement_count
  local regex_line unsafe_regex fixed_prefix bare_prefix

  regex_line='if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then'
  unsafe_regex='if [[ -z "$device_serial" ]]; then'
  fixed_prefix='adb -s "$device_serial" '
  bare_prefix='adb '

  extracted_count="$(device_safety_extract_device_blocks mutation-source "$source_path" "$blocks_dir")" || return 1
  [[ "$extracted_count" == 1 ]] || return 1
  source_block="$blocks_dir/block-1.bash"
  baseline_path="$mutated_path.baseline"
  {
    printf '%s\n' '# temporary mutation skill' '```bash'
    awk '{ print }' "$source_block"
    printf '%s\n' '```'
  } >"$baseline_path"

  awk \
    -v mutation_kind="$mutation_kind" \
    -v regex_line="$regex_line" \
    -v unsafe_regex="$unsafe_regex" \
    -v fixed_prefix="$fixed_prefix" \
    -v bare_prefix="$bare_prefix" \
    -v count_path="$count_path" '
      {
        line = $0
        if (replacement_count == 0 && mutation_kind == "regex" && line == regex_line) {
          line = unsafe_regex
          replacement_count++
        }
        if (replacement_count == 0 && mutation_kind == "bare" &&
          line ~ /^[[:space:]]*adb -s "\$device_serial" /) {
          prefix_at = index(line, fixed_prefix)
          line = substr(line, 1, prefix_at - 1) bare_prefix substr(line, prefix_at + length(fixed_prefix))
          replacement_count++
        }
        print line
      }
      END {
        print replacement_count > count_path
      }
    ' "$source_block" >"$mutated_block" || return 1

  replacement_count="$(<"$count_path")"
  [[ "$replacement_count" == 1 ]] || return 1
  {
    printf '%s\n' '# temporary mutation skill' '```bash'
    awk '{ print }' "$mutated_block"
    printf '%s\n' '```'
  } >"$mutated_path"
  ! cmp -s "$baseline_path" "$mutated_path"
}

device_safety_expect_skill_mutation_rejection() {
  local skill_name="$1" source_path="$2" mutation_kind="$3" expected_error="$4"
  local checker_function="${5:-device_safety_check_skill_file}"
  local mutated_path stderr_path rejected=0 failed=0

  mutated_path="$DEVICE_SAFETY_TMPDIR/skill-mutations/$skill_name-$mutation_kind.md"
  stderr_path="$mutated_path.stderr"
  mkdir -p "${mutated_path%/*}"
  device_safety_mutate_skill_file "$source_path" "$mutated_path" "$mutation_kind" || {
    device_safety_fail "$skill_name $mutation_kind mutation: expected exactly one changed target-block line"
    return
  }
  if (
    DEVICE_SAFETY_FAILURES=0
    "$checker_function" "$skill_name-$mutation_kind" "$mutated_path" 2>"$stderr_path"
    checker_rc=$?
    [[ "$checker_rc" -ne 0 && "$DEVICE_SAFETY_FAILURES" -gt 0 ]]
  ); then
    rejected=1
  fi
  if [[ "$rejected" -ne 1 ]]; then
    device_safety_fail "$skill_name $mutation_kind mutation: unsafe skill must be rejected"
    failed=1
  fi
  if ! grep -Fq "FAIL  $skill_name-$mutation_kind device block 1: $expected_error" "$stderr_path"; then
    device_safety_fail "$skill_name $mutation_kind mutation: expected $expected_error"
    failed=1
  fi
  return "$failed"
}

device_safety_run_skill_mutations() {
  local skill_name skill_path
  local skill_names=(build-services-jar build-sepolicy)
  local skill_paths=(
    ./claude-code/features/.harness/skills/build-services-jar/SKILL.md
    ./claude-code/features/.harness/skills/build-sepolicy/SKILL.md
  )
  local index

  for ((index=0; index<${#skill_names[@]}; index++)); do
    skill_name="${skill_names[$index]}"
    skill_path="${skill_paths[$index]}"
    device_safety_expect_skill_mutation_rejection \
      "$skill_name" "$skill_path" regex 'missing safe serial preflight'
    device_safety_expect_skill_mutation_rejection \
      "$skill_name" "$skill_path" bare 'bare adb'
  done
}

device_safety_run_skill_mutation_selftest() {
  local fixture_dir regex_path bare_path accepted_path

  fixture_dir="$DEVICE_SAFETY_TMPDIR/skill-mutation-selftest"
  mkdir -p "$fixture_dir"
  regex_path="$fixture_dir/regex-safe.md"
  bare_path="$fixture_dir/bare-safe.md"
  accepted_path="$fixture_dir/accepted-safe.md"
  device_safety_write_synthetic_skill "$regex_path" 'adb -s "$device_serial" root'
  device_safety_write_synthetic_skill "$bare_path" 'adb -s "$device_serial" shell service list'

  device_safety_expect_skill_mutation_rejection \
    synthetic-regex "$regex_path" regex 'missing safe serial preflight'
  device_safety_expect_skill_mutation_rejection \
    synthetic-bare "$bare_path" bare 'bare adb'
  device_safety_write_synthetic_skill "$accepted_path" 'adb -s "$device_serial" root'
  if ! (
    DEVICE_SAFETY_FAILURES=0
    device_safety_expect_skill_mutation_rejection \
      synthetic-accepted "$accepted_path" regex 'missing safe serial preflight' \
      device_safety_accept_unsafe_checker 2>/dev/null
    [[ "$DEVICE_SAFETY_FAILURES" -gt 0 ]]
  ); then
    device_safety_fail 'synthetic accepted mutation: outer assertion must retain failure'
  fi
}

device_safety_accept_unsafe_checker() {
  return 0
}

device_safety_run_skills() {
  device_safety_run_skill_contract
  [[ "$DEVICE_SAFETY_FAILURES" -eq 0 ]] || return
  device_safety_run_skill_mutations
}

device_safety_write_synthetic_skill() {
  local path="$1" adb_line="$2" preflight_mode="${3:-safe}"

  printf '%s\n' '# synthetic skill' '```bash' >"$path"
  case "$preflight_mode" in
    safe)
      printf '%s\n' \
        'device_serial="${ANDROID_SERIAL-}"' \
        'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
        '  exit 2' \
        'fi' >>"$path"
      ;;
    duplicate)
      printf '%s\n' \
        'device_serial="${ANDROID_SERIAL-}"' \
        'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
        '  exit 2' \
        'fi' \
        'device_serial="${ANDROID_SERIAL-}"' \
        'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
        '  exit 2' \
        'fi' >>"$path"
      ;;
    same-line)
      printf '%s\n' \
        'device_serial="${ANDROID_SERIAL-}"; device_serial="${ANDROID_SERIAL-}"' \
        'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
        '  exit 2' \
        'fi' >>"$path"
      ;;
    comment)
      printf '%s\n' \
        '# device_serial="${ANDROID_SERIAL-}"' \
        '# if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' >>"$path"
      ;;
    reassignment)
      printf '%s\n' \
        'device_serial="${ANDROID_SERIAL-}"' \
        'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
        '  exit 2' \
        'fi' \
        'device_serial="$other_serial"' >>"$path"
      ;;
    append)
      printf '%s\n' \
        'device_serial="${ANDROID_SERIAL-}"' \
        'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
        '  exit 2' \
        'fi' \
        'device_serial+=-other' >>"$path"
      ;;
    *)
      return 2
      ;;
  esac
  printf '%s\n' "$adb_line" '```' >>"$path"
}

device_safety_expect_synthetic_skill_rejection() {
  local case_name="$1" path="$2"

  if ! (
    DEVICE_SAFETY_FAILURES=0
    device_safety_check_skill_file "synthetic-$case_name" "$path"
    checker_rc=$?
    [[ "$checker_rc" -ne 0 && "$DEVICE_SAFETY_FAILURES" -gt 0 ]]
  ); then
    device_safety_fail "synthetic $case_name: unsafe ADB contract must be rejected"
  fi
}

device_safety_run_skill_contract_selftest() {
  local fixture_dir safe_path chained_path devices_path other_serial_path duplicate_path
  local zero_arg_path operator_path same_line_path comment_path reassignment_path
  local redirect_path append_path

  fixture_dir="$DEVICE_SAFETY_TMPDIR/skill-contract-selftest"
  mkdir -p "$fixture_dir"
  safe_path="$fixture_dir/safe.md"
  chained_path="$fixture_dir/chained.md"
  devices_path="$fixture_dir/devices.md"
  other_serial_path="$fixture_dir/other-serial.md"
  duplicate_path="$fixture_dir/duplicate.md"
  zero_arg_path="$fixture_dir/zero-arg.md"
  operator_path="$fixture_dir/operator.md"
  same_line_path="$fixture_dir/same-line.md"
  comment_path="$fixture_dir/comment.md"
  reassignment_path="$fixture_dir/reassignment.md"
  redirect_path="$fixture_dir/redirect.md"
  append_path="$fixture_dir/append.md"

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
    'adb -s "$device_serial" root' duplicate
  device_safety_expect_synthetic_skill_rejection duplicate-preflight "$duplicate_path"

  device_safety_write_synthetic_skill "$zero_arg_path" \
    'adb -s "$device_serial" root; adb;' safe
  device_safety_expect_synthetic_skill_rejection zero-arg "$zero_arg_path"

  device_safety_write_synthetic_skill "$operator_path" \
    'adb -s "$device_serial" root && adb&&' safe
  device_safety_expect_synthetic_skill_rejection operator-adb "$operator_path"

  device_safety_write_synthetic_skill "$same_line_path" \
    'adb -s "$device_serial" root' same-line
  device_safety_expect_synthetic_skill_rejection same-line-preflight "$same_line_path"

  device_safety_write_synthetic_skill "$comment_path" \
    'adb -s "$device_serial" root' comment
  device_safety_expect_synthetic_skill_rejection comment-preflight "$comment_path"

  device_safety_write_synthetic_skill "$reassignment_path" \
    'adb -s "$device_serial" root' reassignment
  device_safety_expect_synthetic_skill_rejection reassignment "$reassignment_path"

  device_safety_write_synthetic_skill "$redirect_path" \
    'adb -s "$device_serial" root; adb>/tmp/adb.out' safe
  device_safety_expect_synthetic_skill_rejection redirect-adb "$redirect_path"

  device_safety_write_synthetic_skill "$append_path" \
    'adb -s "$device_serial" root' append
  device_safety_expect_synthetic_skill_rejection append-serial "$append_path"
}

device_safety_run_legacy() {
  local legacy_tests legacy_test fake_bin

  device_safety_fake_adb_install legacy demo-serial
  fake_bin="$DEVICE_SAFETY_FAKE_BIN"
  legacy_tests=(
    './claude-code/features/.harness/tests/test-harness.sh'
    './codex/tests/test-harness.sh'
    './common/tests/test-harness.sh'
  )

  for legacy_test in "${legacy_tests[@]}"; do
    PATH="$fake_bin:$PATH" bash "$legacy_test" ||
      device_safety_fail "legacy failed: $legacy_test"
  done
}

device_safety_run_all() {
  local scope

  for scope in fixture claude-invalid-serial claude-valid-serial flag-demo skills legacy; do
    device_safety_run_scope "$scope" || return $?
    [[ "$DEVICE_SAFETY_FAILURES" -eq 0 ]] || return 1
  done
}

main() {
  local scope

  if [[ "$#" -ne 0 ]]; then
    printf 'error: test-device-safety.sh accepts no positional arguments\n' >&2
    return 2
  fi

  DEVICE_SAFETY_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/device-safety.XXXXXX")" || return 1
  trap device_safety_cleanup EXIT

  scope="${DEVICE_SAFETY_TEST_SCOPE:-all}"
  device_safety_run_scope "$scope" || return $?
  [[ "$DEVICE_SAFETY_FAILURES" -eq 0 ]] || return 1
  [[ "$scope" != all ]] || printf 'RESULT PASS  device safety\n'
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
device_safety_register_scope legacy device_safety_run_legacy
device_safety_register_scope all device_safety_run_all
main "$@"
