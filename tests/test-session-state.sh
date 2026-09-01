#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROVIDER="$ROOT/common/.harness/lib/session-state.sh"
TMP_TEST=$(mktemp -d "${TMPDIR:-/tmp}/session-state-test.XXXXXX")
cleanup() { rm -rf "$TMP_TEST"; }
trap cleanup EXIT

fail() { printf 'FAIL %s\n' "$1" >&2; exit 1; }
capture_api() {
  local out err rc
  out=$(mktemp "$TMP_TEST/out.XXXXXX")
  err=$(mktemp "$TMP_TEST/err.XXXXXX")
  "$@" >"$out" 2>"$err"; rc=$?
  API_OUT=$(<"$out") API_ERR=$(<"$err") API_RC=$rc
  rm -f "$out" "$err"
}
assert_api() {
  [[ "$API_RC" == "$1" ]] || fail "$2: rc=$API_RC expected=$1"
  [[ "$API_OUT" == "$3" ]] || fail "$2: stdout mismatch"
  [[ "$API_ERR" == "$4" ]] || fail "$2: stderr mismatch"
}

[[ -f "$PROVIDER" ]] || fail 'validate valid: provider missing'
# shellcheck source=/dev/null
source "$PROVIDER" || fail 'validate valid: source failed'

valid_1=$(printf 'a')
valid_128=$(printf 'a%.0s' {1..128})
capture_api harness_validate_feature_name "$valid_1"
assert_api 0 'validate valid' '' ''
capture_api harness_validate_feature_name "$valid_128"
assert_api 0 'validate 128-byte' '' ''

invalid_names=('' '.' '..' '-a' 'a/b' 'a\\b' 'a b' $'a\nb' 'é' "${valid_128}a")
for name in "${invalid_names[@]}"; do
  capture_api harness_validate_feature_name "$name"
  assert_api 2 'validate invalid' '' 'error: invalid feature name'
done

capture_api harness_validate_feature_name
assert_api 2 'validate arity zero' '' 'error: invalid feature name'
capture_api harness_validate_feature_name a b
assert_api 2 'validate arity extra' '' 'error: invalid feature name'

printf 'RESULT PASS  session state\n'
