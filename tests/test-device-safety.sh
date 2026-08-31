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
main "$@"
