#!/usr/bin/env bash
set -u
export LC_ALL=C

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
PROVIDER="$ROOT/common/.harness/lib/session-state-path.sh"
TMP_TEST=$(mktemp -d "${TMPDIR:-/tmp}/session-path-races-03a2.XXXXXX")
trap 'rm -rf -- "$TMP_TEST"' EXIT
SUMMARY='RESULT PASS  session path race assurance'

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

case ${1:-all} in
  --dependency-absent)
    [[ $# == 1 ]] || fail 'option: dependency-absent takes no value'
    ;;
  all)
    (($# <= 1)) || fail 'option: all takes no value'
    ;;
  *) fail "option: ${1:-empty} unsupported" ;;
esac

CASE_TSV="$TMP_TEST/cases.tsv"
for layer in root project session; do
  for kind in safe-dir link file; do
    printf 'swap-%s-%s\tswap\t%s\t%s\n' "$layer" "$kind" "$layer" "$kind"
  done
done >"$CASE_TSV"
for layer in root project session; do
  printf 'wrong-euid-%s\twrong-euid\t%s\tN/A\n' "$layer" "$layer"
done >>"$CASE_TSV"
for layer in root project session; do
  for kind in safe unsafe disappear; do
    printf 'eexist-%s-%s\teexist\t%s\t%s\n' "$layer" "$kind" "$layer" "$kind"
  done
done >>"$CASE_TSV"
for kind in mkdir-replace mkdir-failure post-mkdir-disappear open-disappear final-stat-disappear; do
  for layer in root project session; do
    printf '%s-%s\t%s\t%s\tN/A\n' "$kind" "$layer" "$kind" "$layer"
  done
done >>"$CASE_TSV"
printf 'real-eio\treal-eio\tN/A\tN/A\n' >>"$CASE_TSV"
[[ -z ${HARNESS_TEST_MATRIX_DAMAGE:-} ]] || printf 'real-eio\treal-eio\tN/A\tN/A\n' >>"$CASE_TSV"

validate_matrix() {
  local counts
  [[ $(wc -l <"$CASE_TSV") == 37 && $(cut -f1 "$CASE_TSV" | sort -u | wc -l) == 37 ]] || return 1
  counts=$(cut -f2 "$CASE_TSV" | uniq -c | awk '{$1=$1; print}' | paste -sd, -)
  [[ $counts == '9 swap,3 wrong-euid,9 eexist,3 mkdir-replace,3 mkdir-failure,3 post-mkdir-disappear,3 open-disappear,3 final-stat-disappear,1 real-eio' ]]
}

matrix_self_disproof() {
  local root=$TMP_TEST/matrix-provider-absent rc
  mkdir -p "$root/tests"
  cp "$SCRIPT_DIR/test-session-path-races.sh" "$root/tests/test-session-path-races.sh"
  set +e
  HARNESS_TEST_MATRIX_DAMAGE=duplicate bash "$root/tests/test-session-path-races.sh" >"$TMP_TEST/matrix-bad.out" 2>"$TMP_TEST/matrix-bad.err"
  rc=$?
  set -e
  [[ $rc == 1 && ! -s $TMP_TEST/matrix-bad.out ]] || fail 'matrix self-disproof'
  ! grep -Fq "$SUMMARY" "$TMP_TEST/matrix-bad.out" || fail 'matrix self-disproof summary'
}

inert_surface() {
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

pass_inert() {
  inert_surface || fail 'dependency absent: inert surface'
  printf '%s\n' "$SUMMARY"
  exit 0
}

validate_matrix || fail '37 unique rows and nine category counts'
matrix_self_disproof
if [[ ! -e $PROVIDER && ! -L $PROVIDER ]]; then
  pass_inert
fi
fail 'dependency classifier incomplete'
