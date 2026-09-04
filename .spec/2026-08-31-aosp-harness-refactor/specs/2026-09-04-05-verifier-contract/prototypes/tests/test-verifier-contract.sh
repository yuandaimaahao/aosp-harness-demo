#!/usr/bin/env bash
set -uo pipefail
if [[ ${1-} =~ ^(boot|system_server|boot_time|crash|service|package)$ ]]; then
  printf '%s\037' "$@" >>"$FAKE_LOG"
  printf '\n' >>"$FAKE_LOG"
  key=$1
  [[ ${FAKE_FAIL-} != "$key" ]] || {
    printf 'runner diagnostic\n' >&2
    exit 7
  }
  case $key in
    boot) value=1 ;;
    system_server) value=1423 ;;
    boot_time) value='btime 100' ;;
    crash) value='' ;;
    service) value='42 sidebar: [x]' ;;
    package) value=package:com.android.sidebar ;;
    *) exit 90 ;;
  esac
  name="FAKE_${key^^}"
  printf '%s' "${!name-$value}"
  exit
fi
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P) || exit 1
SELF=$(realpath "${BASH_SOURCE[0]}") || exit 1
VERIFY="$ROOT/common/.harness/bin/verify-sidebar.sh"
TMP=$(mktemp -d /tmp/verifier-contract.XXXXXX) || exit 1
cleanup() { [[ ! -e $TMP && ! -L $TMP ]] || rm -rf -- "$TMP"; }
trap cleanup EXIT
TMP_REAL=$(realpath "$TMP") || exit 1
OUT="$TMP/out" ERR="$TMP/err" LOG="$TMP/log" EXPECT="$TMP/expect"
fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}
[[ -f $VERIFY && ! -L $VERIFY && -x $VERIFY ]] || fail provider
[[ -d $TMP && ! -L $TMP && $TMP_REAL == "$TMP" && $TMP_REAL != "$ROOT" && $TMP_REAL != "$ROOT"/* ]] || fail temp-path
[[ $(stat -c %u:%a "$TMP") == "$EUID:700" ]] || fail temp-mode
[[ -z $(find "$TMP" -mindepth 1 -print -quit) ]] || fail temp-empty
capture() {
  : >"$OUT"
  : >"$ERR"
  : >"$LOG"
  "$@" >"$OUT" 2>"$ERR"
  RC=$?
}
exact() {
  [[ $RC == "$1" ]] || fail rc
  diff -u "$2" "$OUT" >/dev/null || fail stdout
  [[ ${3-} == stderr-ok || ! -s $ERR ]] || fail stderr
}
expect_call() {
  printf '%s\037' "$@" >>"$EXPECT"
  printf '\n' >>"$EXPECT"
}
PASS="$TMP/pass"
printf '%s\n' 'PASS  boot completed' 'PASS  system_server alive' \
  'PASS  crash-free since baseline' 'PASS  sidebar service registered' \
  'PASS  sidebar package installed' 'SUMMARY PASS=5 FAIL=0 SKIP=0' 'RESULT PASS' >"$PASS"
capture env -i PATH="$PATH" HARNESS_VERIFIER_QUERY_RUNNER="$SELF" FAKE_LOG="$LOG" bash "$VERIFY" --demo
exact 0 "$PASS"
[[ ! -s $LOG ]] || fail demo-query

capture env -i PATH="$PATH" ANDROID_SERIAL=A._:-9 HARNESS_VERIFIER_QUERY_RUNNER="$SELF" FAKE_LOG="$LOG" bash "$VERIFY"
exact 0 "$PASS"
: >"$EXPECT"
expect_call boot -- adb -s A._:-9 shell getprop sys.boot_completed
expect_call system_server -- adb -s A._:-9 shell pidof system_server
expect_call boot_time -- adb -s A._:-9 shell cat /proc/stat
expect_call crash -- adb -s A._:-9 logcat -b crash -d -v epoch,nsec -T 100.000000000
expect_call service -- adb -s A._:-9 shell service list
expect_call package -- adb -s A._:-9 shell pm list packages
cmp -s "$EXPECT" "$LOG" || fail argv

capture env -i PATH="$PATH" ANDROID_SERIAL=0 HARNESS_VERIFIER_QUERY_RUNNER="$SELF" FAKE_LOG="$LOG" FAKE_FAIL=boot bash "$VERIFY" --since 1.2
[[ $RC == 1 && $(tail -n 1 "$OUT") == 'RESULT FAIL' ]] || fail query-rc
grep -Fqx 'FAIL  boot query failed' "$OUT" || fail query-detail
[[ $(cat "$ERR") == 'runner diagnostic' ]] || fail diagnostic
: >"$EXPECT"
expect_call boot -- adb -s 0 shell getprop sys.boot_completed
expect_call system_server -- adb -s 0 shell pidof system_server
expect_call crash -- adb -s 0 logcat -b crash -d -v epoch,nsec -T 1.200000000
expect_call service -- adb -s 0 shell service list
expect_call package -- adb -s 0 shell pm list packages
cmp -s "$EXPECT" "$LOG" || fail explicit-since-argv

for args in '--demo --demo' '--since' '--since 1 extra' '--help --demo' 'position'; do
  read -r -a argv <<<"$args"
  capture env -i PATH="$PATH" HARNESS_VERIFIER_QUERY_RUNNER="$SELF" FAKE_LOG="$LOG" bash "$VERIFY" "${argv[@]}"
  [[ $RC == 2 && ! -s $LOG && ! -s $OUT && -s $ERR ]] || fail "cli $args"
done
capture env -i PATH="$PATH" ANDROID_SERIAL=bad/serial HARNESS_VERIFIER_QUERY_RUNNER="$SELF" FAKE_LOG="$LOG" bash "$VERIFY"
[[ $RC == 2 && ! -s $LOG && ! -s $OUT && -s $ERR ]] || fail serial
capture env -i PATH="$PATH" ANDROID_SERIAL=0 HARNESS_VERIFIER_QUERY_RUNNER=relative FAKE_LOG="$LOG" bash "$VERIFY"
[[ $RC == 2 && ! -s $LOG && ! -s $OUT && -s $ERR ]] || fail runner-preflight
capture env -i PATH="$PATH" HARNESS_VERIFIER_QUERY_RUNNER="$SELF" FAKE_LOG="$LOG" bash "$VERIFY" --help
[[ $RC == 0 && ! -s $ERR && ! -s $LOG && $(cat "$OUT") == 'Usage: verify-sidebar.sh [--demo] [--since EPOCH] [--allow-skip]' ]] || fail help

trap - EXIT
rm -rf -- "$TMP" || exit 1
[[ ! -e $TMP && ! -L $TMP ]] || exit 1
printf '%s\n' 'RESULT PASS  verifier contract'
