#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROVIDER=${PROVIDER:-"$ROOT/common/.harness/lib/session-state.sh"}
TMP_TEST=$(mktemp -d "${TMPDIR:-/tmp}/session-state-test.XXXXXX")
DEFAULT_PROJECTS=()
cleanup() {
  local project root="/tmp/aosp-harness-$EUID"
  for project in "${DEFAULT_PROJECTS[@]}"; do
    rmdir "$root/$project/session" "$root/$project" 2>/dev/null || :
  done
  rmdir "$root" 2>/dev/null || :
  rm -rf "$TMP_TEST"
}
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
SOURCE_SENTINEL_EXPECTED=$(mktemp "$TMP_TEST/source-sentinel.XXXXXX")
printf 'sentinel' >"$SOURCE_SENTINEL_EXPECTED"
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
cmp -s "$SOURCE_FIXTURE/sentinel" "$SOURCE_SENTINEL_EXPECTED" || fail 'source dangerous root: sentinel content changed'
[[ ! -e "$SOURCE_TARGET" && ! -L "$SOURCE_TARGET" ]] || fail 'source dangerous root: target appeared'

# The predicate explicitly pins byte-oriented matching to the C locale.
grep -Fq 'LC_ALL=C' "$PROVIDER" || fail 'validate locale: C locale missing'

declare -F harness_session_state_path >/dev/null || fail 'path HARNESS precedence: function missing'

call_path_env() (
  local harness_set=$1 harness_value=$2 xdg_set=$3 xdg_value=$4 tmp_set=$5 tmp_value=$6
  shift 6
  cd "$TMP_TEST" || exit 1
  unset HARNESS_STATE_ROOT XDG_RUNTIME_DIR TMPDIR
  [[ "$harness_set" == set ]] && export HARNESS_STATE_ROOT=$harness_value
  [[ "$xdg_set" == set ]] && export XDG_RUNTIME_DIR=$xdg_value
  [[ "$tmp_set" == set ]] && export TMPDIR=$tmp_value
  harness_session_state_path "$@"
)
assert_path_mode() {
  [[ -d "$1" ]] || fail "$2: directory missing"
  [[ $(stat -c '%a' "$1") == 700 ]] || fail "$2: mode is not 0700"
}
assert_unsafe_path() {
  local label=$1 absent=$2
  shift 2
  capture_api call_path_env "$@" project session
  assert_api 2 "$label" '' $'error: unsafe session state\n'
  [[ ! -e "$absent" && ! -L "$absent" ]] || fail "$label: created state"
}

PATH_FIXTURE="$TMP_TEST/path-fixture"
mkdir -p "$PATH_FIXTURE/h-physical" "$PATH_FIXTURE/xdg" "$PATH_FIXTURE/tmp"
ln -s h-physical "$PATH_FIXTURE/h-parent"
HARNESS_ROOT="$PATH_FIXTURE/h-parent/root"
HARNESS_PHYSICAL="$PATH_FIXTURE/h-physical/root"
capture_api call_path_env set "$HARNESS_ROOT" set "$PATH_FIXTURE/xdg" set "$PATH_FIXTURE/tmp" project session; assert_api 0 'path HARNESS precedence' "$HARNESS_PHYSICAL/project/session"$'\n' ''
for path in "$HARNESS_PHYSICAL" "$HARNESS_PHYSICAL/project" "$HARNESS_PHYSICAL/project/session"; do assert_path_mode "$path" 'path HARNESS fresh'; done

XDG_PROJECT=xdg-project
XDG_ROOT=$(cd "$PATH_FIXTURE/xdg" && pwd -P)/aosp-harness-$EUID
capture_api call_path_env unset '' set "$PATH_FIXTURE/xdg" set "$PATH_FIXTURE/tmp" "$XDG_PROJECT" session; assert_api 0 'path XDG selection' "$XDG_ROOT/$XDG_PROJECT/session"$'\n' ''

TMP_PROJECT=tmp-project
TMP_ROOT=$(cd "$PATH_FIXTURE/tmp" && pwd -P)/aosp-harness-$EUID
capture_api call_path_env unset '' unset '' set "$PATH_FIXTURE/tmp" "$TMP_PROJECT" session; assert_api 0 'path TMP selection' "$TMP_ROOT/$TMP_PROJECT/session"$'\n' ''

DEFAULT_PROJECT="default-project-$$"
DEFAULT_PROJECTS+=("$DEFAULT_PROJECT")
capture_api call_path_env unset '' unset '' unset '' "$DEFAULT_PROJECT" session; assert_api 0 'path default selection' "/tmp/aosp-harness-$EUID/$DEFAULT_PROJECT/session"$'\n' ''
EMPTY_TMP_PROJECT="empty-tmp-project-$$"
DEFAULT_PROJECTS+=("$EMPTY_TMP_PROJECT")
capture_api call_path_env unset '' unset '' set '' "$EMPTY_TMP_PROJECT" session; assert_api 0 'path empty TMP selection' "/tmp/aosp-harness-$EUID/$EMPTY_TMP_PROJECT/session"$'\n' ''

INVALID_ROOT="$PATH_FIXTURE/invalid-root"
capture_api call_path_env set "$INVALID_ROOT" unset '' unset ''; assert_api 2 'path arity zero' '' $'error: unsafe session state\n'
capture_api call_path_env set "$INVALID_ROOT" unset '' unset '' project session extra; assert_api 2 'path arity extra' '' $'error: unsafe session state\n'
for ids in '. session' 'project ..' '-project session' 'project bad/session' 'project bad\\session' 'project bad session'; do
  read -r project session extra <<<"$ids"
  [[ -z "${extra:-}" ]] || session="$session $extra"
  capture_api call_path_env set "$INVALID_ROOT" unset '' unset '' "$project" "$session"
  assert_api 2 'path invalid id' '' $'error: unsafe session state\n'
done
[[ ! -e "$INVALID_ROOT" ]] || fail 'path invalid id: created state'

mkdir "$PATH_FIXTURE/dot-parent"
assert_unsafe_path 'path HARNESS empty' "$PATH_FIXTURE/unused" set '' unset '' unset ''
assert_unsafe_path 'path HARNESS relative' "$TMP_TEST/relative" set relative unset '' unset ''
assert_unsafe_path 'path HARNESS dot component' "$PATH_FIXTURE/dot-root" set "$PATH_FIXTURE/dot-parent/../dot-root" unset '' unset ''
assert_unsafe_path 'path HARNESS control' "$PATH_FIXTURE/newline" set "$PATH_FIXTURE/"$'new\nline' unset '' unset ''
assert_unsafe_path 'path HARNESS missing parent' "$PATH_FIXTURE/missing/root" set "$PATH_FIXTURE/missing/root" unset '' unset ''
assert_unsafe_path 'path HARNESS slash' /project set / unset '' unset ''

assert_unsafe_path 'path XDG empty' "$PATH_FIXTURE/aosp-harness-$EUID" unset '' set '' unset ''
assert_unsafe_path 'path XDG relative' "$TMP_TEST/relative/aosp-harness-$EUID" unset '' set relative unset ''
assert_unsafe_path 'path XDG dot component' "$PATH_FIXTURE/dot-root/aosp-harness-$EUID" unset '' set "$PATH_FIXTURE/dot-parent/../dot-root" unset ''
assert_unsafe_path 'path XDG control' "$PATH_FIXTURE/newline/aosp-harness-$EUID" unset '' set "$PATH_FIXTURE/"$'new\nline' unset ''
assert_unsafe_path 'path XDG missing base' "$PATH_FIXTURE/missing-xdg/aosp-harness-$EUID" unset '' set "$PATH_FIXTURE/missing-xdg" unset ''

assert_unsafe_path 'path TMP relative' "$TMP_TEST/relative/aosp-harness-$EUID" unset '' unset '' set relative
assert_unsafe_path 'path TMP dot component' "$PATH_FIXTURE/dot-root/aosp-harness-$EUID" unset '' unset '' set "$PATH_FIXTURE/dot-parent/../dot-root"
assert_unsafe_path 'path TMP control' "$PATH_FIXTURE/newline/aosp-harness-$EUID" unset '' unset '' set "$PATH_FIXTURE/"$'new\nline'
assert_unsafe_path 'path TMP missing base' "$PATH_FIXTURE/missing-tmp/aosp-harness-$EUID" unset '' unset '' set "$PATH_FIXTURE/missing-tmp"

printf 'RESULT PASS  session state\n'
