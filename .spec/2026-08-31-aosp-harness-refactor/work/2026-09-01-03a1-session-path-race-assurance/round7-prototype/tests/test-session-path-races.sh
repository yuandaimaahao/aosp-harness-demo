#!/usr/bin/env bash
# THROWAWAY ROUND7 PROTOTYPE: split race-test entrypoint.
set -u
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
ROOT=${HARNESS_PROTOTYPE_ROOT:-$(cd -- "$SCRIPT_DIR/.." && pwd -P)}
FOUNDATION="$ROOT/common/.harness/lib/session-state-foundation.sh"
PROVIDER="$ROOT/common/.harness/lib/session-state-path.sh"
DRIVER="$SCRIPT_DIR/lib/session-path-race-driver.py"
TMP_TEST=$(mktemp -d "${TMPDIR:-/tmp}/session-path-races-round7.XXXXXX")
trap 'rm -rf "$TMP_TEST"' EXIT
SUMMARY='RESULT PASS  session path race assurance'
DRIVER_SUMMARY='RESULT PASS  session path race driver'
DRIVER_PROTOCOL='session-path-race-driver-v1'
fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}
case ${1:-all} in
  --dependency-absent)
    [[ $# == 1 ]] || fail 'option: dependency-absent takes no value'
    GROUP=dependency-absent
    ;;
  all)
    (($# <= 1)) || fail 'option: all takes no value'
    GROUP=all
    ;;
  *) fail "option: ${1:-empty} unsupported" ;;
esac
CASE_LOG="$TMP_TEST/driver/cases.log"
CASE_TSV="$TMP_TEST/cases.tsv"
for layer in root project session; do for kind in safe-dir link file; do printf 'swap-%s-%s\tswap\t%s\t%s\n' "$layer" "$kind" "$layer" "$kind"; done; done >"$CASE_TSV"
for layer in root project session; do printf 'wrong-euid-%s\twrong-euid\t%s\tN/A\n' "$layer" "$layer"; done >>"$CASE_TSV"
for layer in root project session; do for kind in safe unsafe disappear; do printf 'eexist-%s-%s\teexist\t%s\t%s\n' "$layer" "$kind" "$layer" "$kind"; done; done >>"$CASE_TSV"
for kind in mkdir-replace mkdir-failure post-mkdir-disappear open-disappear final-stat-disappear; do
  for layer in root project session; do printf '%s-%s\t%s\t%s\tN/A\n' "$kind" "$layer" "$kind" "$layer"; done
done >>"$CASE_TSV"
printf 'real-eio\treal-eio\tN/A\tN/A\n' >>"$CASE_TSV"
[[ -z ${HARNESS_PROTOTYPE_MATRIX_DAMAGE:-} ]] || printf 'real-eio\treal-eio\tN/A\tN/A\n' >>"$CASE_TSV"
[[ $(wc -l <"$CASE_TSV") == 37 && $(cut -f1 "$CASE_TSV" | sort -u | wc -l) == 37 ]] || fail '37 unique matrix rows'
counts=$(cut -f2 "$CASE_TSV" | uniq -c | awk '{$1=$1; print}' | paste -sd, -)
[[ $counts == '9 swap,3 wrong-euid,9 eexist,3 mkdir-replace,3 mkdir-failure,3 post-mkdir-disappear,3 open-disappear,3 final-stat-disappear,1 real-eio' ]] || fail 'nine category counts'
matrix_self_disproof() {
  local root=$TMP_TEST/matrix-provider-absent rc
  mkdir -p "$root"
  set +e
  HARNESS_PROTOTYPE_ROOT=$root HARNESS_PROTOTYPE_MATRIX_DAMAGE=duplicate bash "$SCRIPT_DIR/test-session-path-races.sh" >"$TMP_TEST/matrix-bad.out" 2>"$TMP_TEST/matrix-bad.err"
  rc=$?
  set -e
  [[ $rc == 1 && ! -s $TMP_TEST/matrix-bad.out ]] && ! grep -Fq "$SUMMARY" "$TMP_TEST/matrix-bad.out" || fail 'matrix self-disproof'
}
matrix_self_disproof
inert() {
  PROVIDER=$PROVIDER bash <<'SH'
set -u
unset HARNESS_SESSION_STATE_PROVIDER_VERSION
unset -f harness_validate_feature_name _harness_session_state_foundation_path _harness_session_state_run \
  _harness_session_path_core harness_session_state_path harness_session_state_write \
  harness_session_state_read harness_session_state_remove 2>/dev/null || :
[[ ! -f $PROVIDER ]] || source "$PROVIDER"
! declare -F _harness_session_path_core >/dev/null || exit 1
for name in harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove; do
  ! declare -F "$name" >/dev/null || exit 1
done
[[ ! -v HARNESS_SESSION_STATE_PROVIDER_VERSION ]]
SH
}
core_available() {
  [[ -f $PROVIDER && -f $FOUNDATION ]] \
    && bash -c 'source "$1"; source "$2"; declare -F _harness_session_path_core >/dev/null' \
      _ "$FOUNDATION" "$PROVIDER" >/dev/null 2>&1
}
validate_provider_anchors() {
  local marker count
  for marker in HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN HARNESS_TEST_MARKER_EXPECTED_EUID HARNESS_TEST_MARKER_OS_ERROR; do
    count=$(grep -Fo "$marker" "$PROVIDER" | wc -l)
    [[ $count == 1 ]] || return 1
  done
}
pass_inert() {
  inert || fail 'dependency absent: inert surface'
  printf '%s\n' "$SUMMARY"
  exit 0
}
if [[ ! -f $PROVIDER ]]; then
  pass_inert
fi
if ! validate_provider_anchors; then
  fail 'provider anchors: expected each exactly once'
fi
if [[ -L $DRIVER || (-e $DRIVER && ! -f $DRIVER) ]]; then
  fail 'race driver: expected regular non-symlink file'
fi
if [[ ! -e $DRIVER ]]; then
  pass_inert
fi
if ! protocol=$(python3 "$DRIVER" protocol) || [[ $protocol != "$DRIVER_PROTOCOL" ]]; then
  fail 'race driver protocol'
fi
if [[ $GROUP == dependency-absent ]] || ! core_available; then
  pass_inert
fi
if ! driver_output=$(python3 "$DRIVER" run-matrix "$FOUNDATION" "$PROVIDER" "$TMP_TEST/driver" "$CASE_TSV" "$CASE_LOG"); then
  fail 'race driver'
fi
[[ $driver_output == "$DRIVER_SUMMARY" ]] || fail 'race driver output'
cut -f1 "$CASE_TSV" >"$TMP_TEST/expected.log"
cmp -s "$CASE_LOG" "$TMP_TEST/expected.log" || fail '37-case matrix'
[[ $(wc -l <"$CASE_LOG") == 37 && $(sort -u "$CASE_LOG" | wc -l) == 37 ]] || fail '37 unique cases'
printf '%s\n' "$SUMMARY"
