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
  local expected_prefix adb_line trimmed adb_count adb_tokens adb_token_count

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
  first_adb="$(grep -nEm1 '(^|[^[:alnum:]_])adb($|[[:space:]])' "$block" | cut -d: -f1)"
  serial_at="$(grep -nFm1 "$serial_line" "$block" | cut -d: -f1)"
  regex_at="$(grep -nFm1 "$regex_line" "$block" | cut -d: -f1)"
  serial_count="$(grep -Foc "$serial_line" "$block")"
  regex_count="$(grep -Foc "$regex_line" "$block")"
  if [[ "$serial_count" != 1 || "$regex_count" != 1 ||
    -z "$first_adb" || -z "$serial_at" || -z "$regex_at" ||
    "$serial_at" -ge "$first_adb" || "$regex_at" -ge "$first_adb" ]]; then
    device_safety_fail "$skill_name device block 1: missing safe serial preflight"
    return 1
  fi

  expected_prefix='adb -s "$device_serial" '
  adb_count=0
  while IFS= read -r adb_line; do
    adb_tokens="$(grep -oE '(^|[^[:alnum:]_])adb($|[[:space:]])' <<<"$adb_line")"
    adb_token_count="$(grep -c . <<<"$adb_tokens")"
    adb_count=$((adb_count + adb_token_count))
    trimmed="${adb_line#"${adb_line%%[![:space:]]*}"}"
    [[ "$adb_token_count" -eq 1 && "$trimmed" == "$expected_prefix"* ]] || {
      device_safety_fail "$skill_name device block 1: bare adb"
      return 1
    }
  done < <(grep -E '(^|[^[:alnum:]_])adb($|[[:space:]])' "$block")

  [[ "$adb_count" -gt 0 ]] || {
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
  local path="$1" adb_line="$2" repeat_preflight="${3:-0}"

  printf '%s\n' \
    '# synthetic skill' \
    '```bash' \
    'device_serial="${ANDROID_SERIAL-}"' \
    'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
    '  exit 2' \
    'fi' >"$path"
  if [[ "$repeat_preflight" -eq 1 ]]; then
    printf '%s\n' \
      'device_serial="${ANDROID_SERIAL-}"' \
      'if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then' \
      '  exit 2' \
      'fi' >>"$path"
  fi
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

  fixture_dir="$DEVICE_SAFETY_TMPDIR/skill-contract-selftest"
  mkdir -p "$fixture_dir"
  safe_path="$fixture_dir/safe.md"
  chained_path="$fixture_dir/chained.md"
  devices_path="$fixture_dir/devices.md"
  other_serial_path="$fixture_dir/other-serial.md"
  duplicate_path="$fixture_dir/duplicate.md"

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
    'adb -s "$device_serial" root' 1
  device_safety_expect_synthetic_skill_rejection duplicate-preflight "$duplicate_path"
}

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
device_safety_register_scope claude-valid-serial device_safety_run_claude_valid_serial_matrix
device_safety_register_scope claude-flag-demo device_safety_run_claude_flag_demo_matrix
device_safety_register_scope codex-flag-demo device_safety_run_codex_flag_demo_matrix
device_safety_register_scope flag-demo device_safety_run_flag_and_demo_matrix
device_safety_register_scope skill-blocks device_safety_run_skill_blocks
device_safety_register_scope skill-contract device_safety_run_skill_contract
device_safety_register_scope skill-contract-selftest device_safety_run_skill_contract_selftest
main "$@"
