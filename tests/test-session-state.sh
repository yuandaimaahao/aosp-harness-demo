#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROVIDER="$ROOT/common/.harness/lib/session-state.sh"
TMP_TEST=$(mktemp -d "${TMPDIR:-/tmp}/session-state-test.XXXXXX")
cleanup() { rm -rf "$TMP_TEST"; }
trap cleanup EXIT

fail() { printf 'FAIL %s\n' "$1" >&2; exit 1; }
capture_api() {
  API_OUT_FILE=$(mktemp "$TMP_TEST/out.XXXXXX")
  API_ERR_FILE=$(mktemp "$TMP_TEST/err.XXXXXX")
  "$@" >"$API_OUT_FILE" 2>"$API_ERR_FILE"
  API_RC=$?
}
assert_api() {
  [[ "$API_RC" == "$1" ]] || fail "$2: rc=$API_RC expected=$1"
  local expected_out expected_err
  expected_out=$(mktemp "$TMP_TEST/expected-out.XXXXXX")
  expected_err=$(mktemp "$TMP_TEST/expected-err.XXXXXX")
  printf '%s' "$3" >"$expected_out"
  printf '%s' "$4" >"$expected_err"
  cmp -s "$API_OUT_FILE" "$expected_out" || fail "$2: stdout mismatch"
  cmp -s "$API_ERR_FILE" "$expected_err" || fail "$2: stderr mismatch"
}

[[ -f "$PROVIDER" ]] || fail 'validate valid: provider missing'
# shellcheck source=/dev/null
source "$PROVIDER" || fail 'validate valid: source failed'

valid_1=$(printf 'a')
valid_128=$(printf 'a%.0s' {1..128})
capture_api harness_validate_feature_name 'a._-Z9'
assert_api 0 'validate punctuation valid' '' ''
capture_api harness_validate_feature_name "$valid_1"
assert_api 0 'validate valid' '' ''
capture_api harness_validate_feature_name "$valid_128"
assert_api 0 'validate 128-byte' '' ''

invalid_names=('' '.' '..' '-a' 'a/b' 'a\\b' 'a b' $'a\nb' 'é' "${valid_128}a")
for name in "${invalid_names[@]}"; do
  capture_api harness_validate_feature_name "$name"
  assert_api 2 'validate invalid' '' $'error: invalid feature name\n'
done

capture_api harness_validate_feature_name
assert_api 2 'validate arity zero' '' $'error: invalid feature name\n'
capture_api harness_validate_feature_name a b
assert_api 2 'validate arity extra' '' $'error: invalid feature name\n'

# Sourcing is definition-only: even a dangerous root must not be parsed or
# touched until an operation is called. Keep an independent inode/content oracle.
SOURCE_FIXTURE=$(mktemp -d "$TMP_TEST/source-fixture.XXXXXX")
printf 'sentinel' >"$SOURCE_FIXTURE/sentinel"
SOURCE_TARGET="$SOURCE_FIXTURE/dangerous-root"
before=$(find "$SOURCE_FIXTURE" -mindepth 1 -maxdepth 2 -printf '%P %i %s\n' | LC_ALL=C sort)
source_out=$(mktemp "$TMP_TEST/source-out.XXXXXX")
source_err=$(mktemp "$TMP_TEST/source-err.XXXXXX")
(
  cd "$SOURCE_FIXTURE" || exit 1
  export HARNESS_STATE_ROOT='./dangerous-root'
  # shellcheck source=/dev/null
  source "$PROVIDER"
) >"$source_out" 2>"$source_err"; source_rc=$?
after=$(find "$SOURCE_FIXTURE" -mindepth 1 -maxdepth 2 -printf '%P %i %s\n' | LC_ALL=C sort)
[[ "$source_rc" == 0 ]] || fail 'source dangerous root: rc'
[[ ! -s "$source_out" && ! -s "$source_err" ]] || fail 'source dangerous root: output'
[[ "$before" == "$after" ]] || fail 'source dangerous root: fixture changed'
[[ ! -e "$SOURCE_TARGET" && ! -L "$SOURCE_TARGET" ]] || fail 'source dangerous root: target appeared'

# The predicate explicitly pins byte-oriented matching to the C locale.
grep -Fq 'LC_ALL=C' "$PROVIDER" || fail 'validate locale: C locale missing'

printf 'RESULT PASS  session state\n'
