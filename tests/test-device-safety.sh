#!/usr/bin/env bash
set -u

DEVICE_SAFETY_SCOPE_NAMES=() DEVICE_SAFETY_SCOPE_FUNCS=()
DEVICE_SAFETY_FAILURES=0 DEVICE_SAFETY_TMPDIR=''
SKILL_NAMES=(build-services-jar build-sepolicy)
SKILL_PATHS=(
  ./claude-code/features/.harness/skills/build-services-jar/SKILL.md
  ./claude-code/features/.harness/skills/build-sepolicy/SKILL.md
)
SERIAL_INIT='device_serial="${ANDROID_SERIAL-}"'
SERIAL_GUARD='if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then'
SERIAL_RUNTIME_GUARD='if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ || ! "$instance_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]; then'
ADB_PREFIX='adb -s "$device_serial" '

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
  for ((i = 0; i < ${#DEVICE_SAFETY_SCOPE_NAMES[@]}; i++)); do
    [[ "${DEVICE_SAFETY_SCOPE_NAMES[$i]}" != "$wanted" ]] || {
      "${DEVICE_SAFETY_SCOPE_FUNCS[$i]}"
      return
    }
  done
  printf 'error: unknown DEVICE_SAFETY_TEST_SCOPE: %s\n' "$wanted" >&2
  return 2
}
device_safety_cleanup() { [[ -z "$DEVICE_SAFETY_TMPDIR" ]] || rm -rf "$DEVICE_SAFETY_TMPDIR"; }

device_safety_fake_adb_install() {
  local dir="$DEVICE_SAFETY_TMPDIR/$1"
  mkdir -p "$dir/bin"
  ADB_LOG="$dir/adb.log" EXPECTED_SERIAL="$2" DEVICE_SAFETY_FAKE_BIN="$dir/bin"
  export ADB_LOG EXPECTED_SERIAL DEVICE_SAFETY_FAKE_BIN
  : >"$ADB_LOG"
  cat >"$dir/bin/adb" <<'EOF'
#!/usr/bin/env bash
printf 'adb ' >>"$ADB_LOG"; printf '%q ' "$@" >>"$ADB_LOG"; printf '\n' >>"$ADB_LOG"
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
  chmod +x "$dir/bin/adb"
}

device_safety_run_fixture() {
  local row command expected output rc fake argv
  device_safety_fake_adb_install fixture demo-serial
  fake="$DEVICE_SAFETY_FAKE_BIN/adb"
  [[ "$(PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" command -v adb)" == "$fake" ]] || device_safety_fail 'fixture: private fake adb bin must be first in PATH'
  trap -p EXIT | grep -Fq device_safety_cleanup || device_safety_fail 'fixture: cleanup trap must be registered'
  for row in 'shell getprop sys.boot_completed|1' 'shell pidof system_server|1423' 'shell cat /proc/stat|btime 200' 'shell service list|52 sidebar: [android.sidebar.ISidebar]' 'shell pm list packages|package:com.android.sidebar'; do
    command="${row%%|*}" expected="${row#*|}"
    read -r -a argv <<<"$command"
    output="$(PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" adb -s demo-serial "${argv[@]}")" || device_safety_fail "fixture: expected $command response to succeed"
    [[ "$output" == "$expected" ]] || device_safety_fail "fixture: unexpected $command response"
  done
  PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" adb -s demo-serial logcat -b crash -d -v threadtime -T 200 >/dev/null || device_safety_fail 'fixture: expected logcat response to succeed'
  PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" adb -s other-serial shell getprop sys.boot_completed >/dev/null 2>&1
  rc=$?
  [[ "$rc" -eq 91 ]] || device_safety_fail 'fixture: unknown serial must exit 91'
  PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" adb -s demo-serial unknown command >/dev/null 2>&1
  rc=$?
  [[ "$rc" -eq 92 ]] || device_safety_fail 'fixture: unknown command must exit 92'
  [[ -s "$ADB_LOG" ]] || device_safety_fail 'fixture: fake adb log must be non-empty'
  for command in 'adb -s demo-serial shell getprop sys.boot_completed ' 'adb -s demo-serial logcat -b crash -d -v threadtime -T 200 ' 'adb -s other-serial shell getprop sys.boot_completed ' 'adb -s demo-serial unknown command '; do
    grep -Fq "$command" "$ADB_LOG" || device_safety_fail "fixture: adb log missing $command"
  done
}

device_safety_capture() {
  local fixture="$1" expected="$2" serial="$3"
  shift 3
  device_safety_fake_adb_install "$fixture" "$expected"
  CAPTURE_DIR="$DEVICE_SAFETY_TMPDIR/$fixture" CAPTURE_OUT="$CAPTURE_DIR/stdout" CAPTURE_ERR="$CAPTURE_DIR/stderr"
  if [[ "$serial" == __UNSET__ ]]; then
    env -u ANDROID_SERIAL PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" "$@" >"$CAPTURE_OUT" 2>"$CAPTURE_ERR"
  else
    ANDROID_SERIAL="$serial" PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" "$@" >"$CAPTURE_OUT" 2>"$CAPTURE_ERR"
  fi
  CAPTURE_RC=$?
}

device_safety_run_claude_invalid_serial_matrix() {
  local serial label i=0
  local invalid_serials=(__UNSET__ -bad .bad _bad :bad bad/path 'bad value' $'bad\nvalue' 'bad;value' 'bad+value')
  for serial in "${invalid_serials[@]}"; do
    i=$((i + 1))
    label="$serial"
    [[ "$serial" != __UNSET__ ]] || label=missing
    device_safety_capture "claude-invalid-$i" demo-serial "$serial" bash ./claude-code/features/dev-sidebar/verify-sidebar.sh
    [[ "$CAPTURE_RC" -eq 2 ]] || device_safety_fail "claude $label ANDROID_SERIAL: expected rc=2 and zero adb calls"
    grep -Fq ANDROID_SERIAL "$CAPTURE_ERR" || device_safety_fail "claude $label ANDROID_SERIAL: missing ANDROID_SERIAL error"
    [[ ! -s "$ADB_LOG" ]] || device_safety_fail "claude $label ANDROID_SERIAL: expected zero adb calls"
  done
}

device_safety_run_claude_valid_serial_matrix() {
  local serial i=0
  for serial in demo-serial 'A0._:-z'; do
    i=$((i + 1))
    device_safety_capture "claude-valid-$i" "$serial" "$serial" bash ./claude-code/features/dev-sidebar/verify-sidebar.sh --since 200
    [[ -s "$ADB_LOG" ]] || device_safety_fail "claude $serial: expected non-empty adb log"
    awk -v p="adb -s $serial " 'index($0,p)!=1{exit 1}' "$ADB_LOG" || device_safety_fail "claude $serial: expected adb -s prefix on every call"
    [[ "$CAPTURE_RC" -eq 0 && "$(tail -n 1 "$CAPTURE_OUT")" == 'RESULT PASS' ]] || device_safety_fail "claude $serial: expected rc=0 and RESULT PASS"
  done
}

device_safety_run_flag_and_demo_for() {
  local name="$1" path="$2" serial label i=0
  [[ -x "$path" ]] || {
    device_safety_fail "$name flag-demo: verifier must be executable"
    return
  }
  for serial in __UNSET__ -bad; do
    i=$((i + 1))
    label=invalid
    [[ "$serial" != __UNSET__ ]] || label=missing
    device_safety_capture "$name-flag-$i" demo-serial "$serial" bash "$path" --allow-skip
    [[ "$CAPTURE_RC" -eq 2 ]] && grep -Fq -- '--allow-skip requires --demo' "$CAPTURE_ERR" && ! grep -Fq ANDROID_SERIAL "$CAPTURE_ERR" && [[ ! -s "$ADB_LOG" ]] || device_safety_fail "$name real allow-skip $label serial: expected flag error before ANDROID_SERIAL"
  done
  device_safety_fake_adb_install "$name-demo-skip" demo-serial
  CAPTURE_DIR="$DEVICE_SAFETY_TMPDIR/$name-demo-skip"
  CAPTURE_OUT="$CAPTURE_DIR/stdout"
  CAPTURE_ERR="$CAPTURE_DIR/stderr"
  DEMO_APP_INSTALLED=0 PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH" bash "$path" --demo --allow-skip >"$CAPTURE_OUT" 2>"$CAPTURE_ERR"
  CAPTURE_RC=$?
  [[ "$CAPTURE_RC" -eq 0 ]] || device_safety_fail "$name demo allow-skip: expected rc=0"
  grep -Eq '^SKIP  ' "$CAPTURE_OUT" || device_safety_fail "$name demo allow-skip: expected SKIP detail"
  [[ "$(tail -n 1 "$CAPTURE_OUT")" == 'RESULT PASS (SKIP allowed)' ]] || device_safety_fail "$name demo allow-skip: expected RESULT PASS (SKIP allowed)"
  [[ ! -s "$ADB_LOG" ]] || device_safety_fail "$name demo allow-skip: expected zero adb calls"
}
device_safety_run_claude_flag_demo_matrix() { device_safety_run_flag_and_demo_for claude ./claude-code/features/dev-sidebar/verify-sidebar.sh; }
device_safety_run_codex_flag_demo_matrix() { device_safety_run_flag_and_demo_for codex ./codex/features/dev-sidebar/verify-sidebar.sh; }
device_safety_run_flag_and_demo_matrix() {
  device_safety_run_claude_flag_demo_matrix
  device_safety_run_codex_flag_demo_matrix
}

device_safety_extract_device_blocks() {
  local path="$2" output_dir="$3" in_bash=0 block='' line count=0
  mkdir -p "$output_dir" || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$in_bash" -eq 0 && "$line" == '```bash' ]]; then
      in_bash=1
      block=''
      continue
    fi
    if [[ "$in_bash" -eq 1 && "$line" == '```' ]]; then
      if grep -Eq '(^|[;&][[:space:]]*|--[[:space:]]+)adb[[:space:]].*(root|remount|push|reboot|shell)' <<<"$block"; then
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
  local dir="$DEVICE_SAFETY_TMPDIR/skill-blocks" count i
  mkdir -p "$dir"
  printf '%s\n' '# synthetic' '```bash' 'm services' '```' 'inline `adb shell service list`' '```bash' 'adb root' '```' >"$dir/synthetic.md"
  count="$(device_safety_extract_device_blocks synthetic "$dir/synthetic.md" "$dir/synthetic")" || device_safety_fail 'synthetic: failed to extract fenced device blocks'
  [[ "$count" == 1 ]] && grep -Fqx 'adb root' "$dir/synthetic/block-1.bash" && ! grep -Fq 'm services' "$dir/synthetic/block-1.bash" || device_safety_fail 'synthetic: expected only one fenced device block'
  for ((i = 0; i < ${#SKILL_NAMES[@]}; i++)); do
    count="$(device_safety_extract_device_blocks "${SKILL_NAMES[$i]}" "${SKILL_PATHS[$i]}" "$dir/${SKILL_NAMES[$i]}")" || count=error
    [[ "$count" == 1 ]] || device_safety_fail "${SKILL_NAMES[$i]}: expected exactly one fenced device block"
  done
}

device_safety_check_skill_file() {
  local name="$1" path="$2" dir="$DEVICE_SAFETY_TMPDIR/contract-$1" count block line trimmed rest init guard runtime_adb
  local n=0 first=0 init_at=0 guard_at=0 init_count=0 guard_count=0 adb_count=0 adb_ok=1
  local adb_word='(^|[^[:alnum:]_])adb([^[:alnum:]_]|$)' unsafe='if [[ -z "$device_serial" ]]; then'
  count="$(device_safety_extract_device_blocks "$name" "$path" "$dir")" || count=error
  [[ "$count" == 1 ]] || {
    device_safety_fail "$name: expected exactly one fenced device block"
    return 1
  }
  block="$dir/block-1.bash"
  while IFS= read -r line || [[ -n "$line" ]]; do
    n=$((n + 1))
    trimmed="${line#"${line%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue
    if [[ "$trimmed" == "$SERIAL_INIT" ]]; then
      init_count=$((init_count + 1))
      init_at=$n
      init=1
    else init=0; fi
    if [[ "$trimmed" == "$SERIAL_GUARD" || "$trimmed" == "$SERIAL_RUNTIME_GUARD" ]]; then
      guard_count=$((guard_count + 1))
      guard_at=$n
      guard=1
    else guard=0; fi
    runtime_adb=0
    [[ $trimmed =~ ^bash[[:space:]]+\"\$command_adapter\"[[:space:]]+(query|mutate|reconnect)[[:space:]]+android-device[[:space:]]+--[[:space:]]+adb[[:space:]]+-s[[:space:]]+\"\$device_serial\"[[:space:]] ]] && runtime_adb=1
    if [[ "$trimmed" == *device_serial* && "$init" -eq 0 && "$guard" -eq 0 && "$trimmed" != "$unsafe" && "$trimmed" != "$ADB_PREFIX"* && "$runtime_adb" -eq 0 ]]; then
      device_safety_fail "$name device block 1: device_serial reference not allowed"
      return 1
    fi
    if [[ "$trimmed" =~ $adb_word ]]; then
      [[ "$first" -ne 0 ]] || first=$n
      adb_count=$((adb_count + 1))
      if [[ "$trimmed" == "$ADB_PREFIX"* ]]; then
        rest="${trimmed#adb}"
        [[ "$rest" =~ $adb_word ]] && adb_ok=0
      elif [[ "$runtime_adb" -ne 1 ]]; then
        adb_ok=0
      fi
    fi
  done <"$block"
  if [[ "$init_count" -ne 1 || "$guard_count" -ne 1 || "$first" -eq 0 || "$init_at" -ge "$first" || "$guard_at" -ge "$first" ]]; then
    device_safety_fail "$name device block 1: missing safe serial preflight"
    return 1
  fi
  [[ "$adb_count" -gt 0 && "$adb_ok" -eq 1 ]] || {
    device_safety_fail "$name device block 1: bare adb"
    return 1
  }
}

device_safety_run_skill_contract() {
  local i
  for ((i = 0; i < ${#SKILL_NAMES[@]}; i++)); do device_safety_check_skill_file "${SKILL_NAMES[$i]}" "${SKILL_PATHS[$i]}"; done
}
device_safety_wrap_block() { {
  printf '%s\n' '# temporary mutation skill' '```bash'
  awk '{print}' "$1"
  printf '%s\n' '```'
} >"$2"; }
device_safety_mutate_skill_file() {
  local source="$1" target="$2" kind="$3" block count
  local dir="$target.blocks" count_file="$target.count"
  count="$(device_safety_extract_device_blocks mutation-source "$source" "$dir")"
  [[ "$count" == 1 ]] || return 1
  block="$dir/block-1.bash"
  device_safety_wrap_block "$block" "$target.baseline"
  awk -v kind="$kind" -v guard="$SERIAL_GUARD" -v runtime_guard="$SERIAL_RUNTIME_GUARD" -v prefix="$ADB_PREFIX" -v count_file="$count_file" '
    { line=$0; if (!n && kind=="regex" && (line==guard || line==runtime_guard)) {line="if [[ -z \"$device_serial\" ]]; then"; n++}
      if (!n && kind=="bare" && line ~ /^[[:space:]]*adb -s "\$device_serial" /) {at=index(line,prefix); line=substr(line,1,at-1) "adb " substr(line,at+length(prefix)); n++}
      else if (!n && kind=="bare" && line ~ / -- adb -s "\$device_serial" /) {sub(/ -- adb -s "\$device_serial" /," -- adb ",line); n++} print line }
    END {print n+0 > count_file}' "$block" >"$target.block" || return 1
  [[ "$(<"$count_file")" == 1 ]] || return 1
  device_safety_wrap_block "$target.block" "$target"
  ! cmp -s "$target.baseline" "$target"
}

device_safety_expect_skill_mutation_rejection() {
  local name="$1" source="$2" kind="$3" expected="$4" checker="${5:-device_safety_check_skill_file}" target err rejected=0
  target="$DEVICE_SAFETY_TMPDIR/mutations/$name-$kind.md"
  err="$target.stderr"
  mkdir -p "${target%/*}"
  device_safety_mutate_skill_file "$source" "$target" "$kind" || {
    device_safety_fail "$name $kind mutation: expected exactly one changed target-block line"
    return
  }
  (
    DEVICE_SAFETY_FAILURES=0
    "$checker" "$name-$kind" "$target" 2>"$err"
    rc=$?
    [[ "$rc" -ne 0 && "$DEVICE_SAFETY_FAILURES" -gt 0 ]]
  ) && rejected=1
  [[ "$rejected" -eq 1 ]] || device_safety_fail "$name $kind mutation: unsafe skill must be rejected"
  grep -Fq "FAIL  $name-$kind device block 1: $expected" "$err" || device_safety_fail "$name $kind mutation: expected $expected"
}
device_safety_run_skill_mutations() {
  local i
  for ((i = 0; i < ${#SKILL_NAMES[@]}; i++)); do
    device_safety_expect_skill_mutation_rejection "${SKILL_NAMES[$i]}" "${SKILL_PATHS[$i]}" regex 'missing safe serial preflight'
    device_safety_expect_skill_mutation_rejection "${SKILL_NAMES[$i]}" "${SKILL_PATHS[$i]}" bare 'bare adb'
  done
}
device_safety_accept_unsafe_checker() { return 0; }

device_safety_emit_preflight() { printf '%s\n' "$SERIAL_INIT" "$SERIAL_GUARD" '  exit 2' 'fi'; }
device_safety_write_synthetic_skill() {
  local path="$1" adb_line="$2" mode="${3:-safe}"
  {
    printf '%s\n' '# synthetic skill' '```bash'
    case "$mode" in
      safe) device_safety_emit_preflight ;;
      duplicate)
        device_safety_emit_preflight
        device_safety_emit_preflight
        ;;
      same-line) printf '%s\n' "$SERIAL_INIT; $SERIAL_INIT" "$SERIAL_GUARD" '  exit 2' 'fi' ;;
      comment) printf '# %s\n# %s\n' "$SERIAL_INIT" "$SERIAL_GUARD" ;;
      reassignment)
        device_safety_emit_preflight
        printf '%s\n' 'device_serial="$other_serial"'
        ;;
      append)
        device_safety_emit_preflight
        printf '%s\n' 'device_serial+=-other'
        ;;
      *) return 2 ;;
    esac
    printf '%s\n' "$adb_line" '```'
  } >"$path"
}
device_safety_expect_synthetic_skill_rejection() {
  local name="$1" path="$2"
  (
    DEVICE_SAFETY_FAILURES=0
    device_safety_check_skill_file "synthetic-$name" "$path" >/dev/null 2>&1
    rc=$?
    [[ "$rc" -ne 0 && "$DEVICE_SAFETY_FAILURES" -gt 0 ]]
  ) || device_safety_fail "synthetic $name: unsafe ADB contract must be rejected"
}
device_safety_run_skill_contract_selftest() {
  local dir="$DEVICE_SAFETY_TMPDIR/contract-selftest" i path
  local names=(chained devices other-serial duplicate-preflight zero-arg operator-adb same-line-preflight comment-preflight reassignment redirect-adb append-serial)
  local modes=(safe safe safe duplicate safe safe same-line comment reassignment safe append)
  local commands=('adb -s "$device_serial" root && adb reboot' $'adb -s "$device_serial" root\nadb devices' $'adb -s "$device_serial" root\nadb -s "$other_serial" wait-for-device' 'adb -s "$device_serial" root' 'adb -s "$device_serial" root; adb;' 'adb -s "$device_serial" root && adb&&' 'adb -s "$device_serial" root' 'adb -s "$device_serial" root' 'adb -s "$device_serial" root' 'adb -s "$device_serial" root; adb>/tmp/adb.out' 'adb -s "$device_serial" root')
  mkdir -p "$dir"
  device_safety_write_synthetic_skill "$dir/safe.md" 'adb -s "$device_serial" root'
  device_safety_check_skill_file synthetic-safe "$dir/safe.md" || device_safety_fail 'synthetic safe: expected contract acceptance'
  for ((i = 0; i < ${#names[@]}; i++)); do
    path="$dir/${names[$i]}.md"
    device_safety_write_synthetic_skill "$path" "${commands[$i]}" "${modes[$i]}"
    device_safety_expect_synthetic_skill_rejection "${names[$i]}" "$path"
  done
}
device_safety_run_skill_mutation_selftest() {
  local dir="$DEVICE_SAFETY_TMPDIR/mutation-selftest" path
  mkdir -p "$dir"
  device_safety_write_synthetic_skill "$dir/regex.md" 'adb -s "$device_serial" root'
  device_safety_expect_skill_mutation_rejection synthetic-regex "$dir/regex.md" regex 'missing safe serial preflight'
  device_safety_write_synthetic_skill "$dir/bare.md" 'adb -s "$device_serial" shell service list'
  device_safety_expect_skill_mutation_rejection synthetic-bare "$dir/bare.md" bare 'bare adb'
  path="$dir/accepted.md"
  device_safety_write_synthetic_skill "$path" 'adb -s "$device_serial" root'
  (
    DEVICE_SAFETY_FAILURES=0
    device_safety_expect_skill_mutation_rejection synthetic-accepted "$path" regex 'missing safe serial preflight' device_safety_accept_unsafe_checker 2>/dev/null
    [[ "$DEVICE_SAFETY_FAILURES" -gt 0 ]]
  ) || device_safety_fail 'synthetic accepted mutation: outer assertion must retain failure'
}
device_safety_run_skills() {
  device_safety_run_skill_contract
  [[ "$DEVICE_SAFETY_FAILURES" -ne 0 ]] || device_safety_run_skill_mutations
}

device_safety_run_legacy() {
  local test fake
  device_safety_fake_adb_install legacy demo-serial
  fake="$DEVICE_SAFETY_FAKE_BIN"
  for test in ./claude-code/features/.harness/tests/test-harness.sh ./codex/tests/test-harness.sh ./common/tests/test-harness.sh; do PATH="$fake:$PATH" bash "$test" || device_safety_fail "legacy failed: $test"; done
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
  [[ "$#" -eq 0 ]] || {
    printf 'error: test-device-safety.sh accepts no positional arguments\n' >&2
    return 2
  }
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
