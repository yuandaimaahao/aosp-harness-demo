#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROVIDER=${PROVIDER:-"$ROOT/common/.harness/lib/session-state-foundation.sh"}
DEFAULT_ROOT="/tmp/aosp-harness-$EUID"

# Make the preexisting-empty-root case deterministic. The outer invocation owns
# only the inode it creates; the inner full test must preserve that inode.
if [[ ${HARNESS_TEST_DEFAULT_CHILD:-0} == 0 && ! -e "$DEFAULT_ROOT" && ! -L "$DEFAULT_ROOT" ]]; then
  mkdir -m 700 "$DEFAULT_ROOT"
  wrapper_inode=$(stat -c '%i' "$DEFAULT_ROOT")
  HARNESS_TEST_DEFAULT_CHILD=1 bash "${BASH_SOURCE[0]}"
  wrapper_rc=$?
  wrapper_error=
  if [[ ! -d "$DEFAULT_ROOT" || -L "$DEFAULT_ROOT" ]]; then
    wrapper_error='preexisting default root missing after test'
  elif [[ $(stat -c '%i' "$DEFAULT_ROOT") != "$wrapper_inode" ]]; then
    wrapper_error='preexisting default root inode changed after test'
  elif [[ -n $(find "$DEFAULT_ROOT" -mindepth 1 -print -quit) ]]; then
    wrapper_error='preexisting default root not empty after test'
  else
    rmdir "$DEFAULT_ROOT"
  fi
  (( wrapper_rc == 0 )) || exit "$wrapper_rc"
  [[ -z "$wrapper_error" ]] || { printf 'FAIL %s\n' "$wrapper_error" >&2; exit 1; }
  exit 0
fi

TMP_TEST=$(mktemp -d "${TMPDIR:-/tmp}/session-state-test.XXXXXX")
NAME_SEED=$(mktemp -d "$TMP_TEST/names.XXXXXX")
NAME_SUFFIX=${NAME_SEED##*.}
rmdir "$NAME_SEED"
DEFAULT_ROOT_EXISTED=0
DEFAULT_ROOT_ORIGINAL_INODE=
if [[ -e "$DEFAULT_ROOT" || -L "$DEFAULT_ROOT" ]]; then
  DEFAULT_ROOT_EXISTED=1
  DEFAULT_ROOT_ORIGINAL_INODE=$(stat -c '%i' "$DEFAULT_ROOT")
fi
DEFAULT_PATHS=()
cleanup() {
  local relative
  for relative in "${DEFAULT_PATHS[@]}"; do
    rmdir "$DEFAULT_ROOT/$relative" "$DEFAULT_ROOT/${relative%/*}" 2>/dev/null || :
  done
  if (( DEFAULT_ROOT_EXISTED == 0 )); then
    rmdir "$DEFAULT_ROOT" 2>/dev/null || :
  fi
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
assert_call() {
  local expected_rc=$1 label=$2 expected_out=$3 expected_err=$4
  shift 4
  capture_api "$@"
  assert_api "$expected_rc" "$label" "$expected_out" "$expected_err"
}
[[ -f "$PROVIDER" ]] || fail 'validate valid: provider missing'
# Sourcing is definition-only: all candidate roots remain untouched, exported
# sentinels are byte-identical, and no capability marker appears.
SOURCE_FIXTURE=$(mktemp -d "$TMP_TEST/source-fixture.XXXXXX")
printf 'sentinel' >"$SOURCE_FIXTURE/sentinel"
SOURCE_TARGETS=("$SOURCE_FIXTURE/harness-target" "$SOURCE_FIXTURE/xdg-target" "$SOURCE_FIXTURE/tmp-target")
before=$(find "$SOURCE_FIXTURE" -mindepth 1 -maxdepth 2 -printf '%P %i %s\n' | LC_ALL=C sort)
(
  cd "$SOURCE_FIXTURE" || exit 1
  unset HARNESS_SESSION_STATE_PROVIDER_VERSION
  export HARNESS_STATE_ROOT="${SOURCE_TARGETS[0]}" XDG_RUNTIME_DIR="${SOURCE_TARGETS[1]}" TMPDIR="${SOURCE_TARGETS[2]}"
  declare -p HARNESS_STATE_ROOT XDG_RUNTIME_DIR TMPDIR >"$TMP_TEST/source-before"
  # shellcheck source=/dev/null
  source "$PROVIDER" >"$TMP_TEST/source-out" 2>"$TMP_TEST/source-err"
  printf '%s\n' "$?" >"$TMP_TEST/source-rc"
  declare -p HARNESS_STATE_ROOT XDG_RUNTIME_DIR TMPDIR >"$TMP_TEST/source-after"
  [[ ! -v HARNESS_SESSION_STATE_PROVIDER_VERSION ]] || : >"$TMP_TEST/source-marker"
  declare -f _harness_component_is_safe harness_validate_feature_name _harness_session_state_foundation_path _harness_session_state_run >"$TMP_TEST/source-functions"
)
after=$(find "$SOURCE_FIXTURE" -mindepth 1 -maxdepth 2 -printf '%P %i %s\n' | LC_ALL=C sort)
[[ $(<"$TMP_TEST/source-rc") == 0 ]] || fail 'source dangerous roots: rc'
[[ ! -s "$TMP_TEST/source-out" && ! -s "$TMP_TEST/source-err" ]] || fail 'source dangerous roots: output'
cmp -s "$TMP_TEST/source-before" "$TMP_TEST/source-after" || fail 'source sentinel: declarations changed'
[[ ! -e "$TMP_TEST/source-marker" ]] || fail 'public surface: provider marker must be absent'
[[ "$before" == "$after" ]] || fail 'source dangerous roots: fixture changed'
cmp -s "$SOURCE_FIXTURE/sentinel" <(printf 'sentinel') || fail 'source dangerous roots: sentinel content changed'
for source_target in "${SOURCE_TARGETS[@]}"; do
  [[ ! -e "$source_target" && ! -L "$source_target" ]] || fail 'source dangerous roots: target appeared'
done
# shellcheck source=/dev/null
source "$TMP_TEST/source-functions"
for public_name in harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove; do
  if declare -F "$public_name" >/dev/null; then
    fail "public surface: $public_name must be absent"
  fi
done
declare -F harness_validate_feature_name >/dev/null || fail 'public surface: validate missing'
declare -F _harness_session_state_foundation_path >/dev/null || fail 'private surface: foundation path missing'
declare -F _harness_session_state_run >/dev/null || fail 'private surface: dispatcher missing'
[[ ! -v HARNESS_SESSION_STATE_PROVIDER_VERSION ]] || fail 'public surface: provider marker must be absent'
valid_1=$(printf 'a')
valid_128=$(printf 'a%.0s' {1..128})
assert_call 0 'validate punctuation valid' '' '' harness_validate_feature_name 'a._-Z9'
assert_call 0 'validate valid' '' '' harness_validate_feature_name "$valid_1"
assert_call 0 'validate 128-byte' '' '' harness_validate_feature_name "$valid_128"

invalid_names=('' '.' '..' '-a' 'a/b' 'a\\b' 'a b' $'a\nb' 'é' "${valid_128}a")
for name in "${invalid_names[@]}"; do
  assert_call 2 'validate invalid' '' $'error: invalid feature name\n' harness_validate_feature_name "$name"
done

assert_call 2 'validate arity zero' '' $'error: invalid feature name\n' harness_validate_feature_name
assert_call 2 'validate arity extra' '' $'error: invalid feature name\n' harness_validate_feature_name a b
# The predicate explicitly pins byte-oriented matching to the C locale.
grep -Fq 'LC_ALL=C' "$PROVIDER" || fail 'validate locale: C locale missing'

call_path_env() (
  local harness_set=$1 harness_value=$2 xdg_set=$3 xdg_value=$4 tmp_set=$5 tmp_value=$6
  shift 6
  cd "$CALL_CWD" || exit 1
  unset HARNESS_STATE_ROOT XDG_RUNTIME_DIR TMPDIR
  [[ "$harness_set" == set ]] && export HARNESS_STATE_ROOT=$harness_value
  [[ "$xdg_set" == set ]] && export XDG_RUNTIME_DIR=$xdg_value
  [[ "$tmp_set" == set ]] && export TMPDIR=$tmp_value
  _harness_session_state_foundation_path "$@"
)
object_state() {
  if [[ -e "$1" || -L "$1" ]]; then
    stat -c '%F|%d|%i|%a|%u' -- "$1"
  else
    printf '%s\n' ABSENT
  fi
}
fixture_inventory() {
  {
    find "$PATH_FIXTURE" -mindepth 1 -printf 'fixture/%P|%y|%D|%i|%m|%U\n'
    find "$DEFAULT_ROOT" -mindepth 1 -printf 'default/%P|%y|%D|%i|%m|%U\n'
  } | LC_ALL=C sort
}
assert_fresh_dir() {
  [[ ! -L "$1" ]] || fail "$2: directory is a link"
  [[ $(stat -c '%F' "$1") == directory ]] || fail "$2: stat type is not directory"
  [[ $(stat -c '%u' "$1") == "$EUID" ]] || fail "$2: owner is not EUID"
  [[ $(stat -c '%a' "$1") == 700 ]] || fail "$2: mode is not 0700"
}
assert_unsafe_call() {
  local label=$1 target=$2 before_fixture before_target after_fixture after_target
  shift 2
  before_fixture=$(fixture_inventory)
  before_target=$(object_state "$target")
  capture_api "$@"
  assert_api 2 "$label" '' $'error: unsafe session state\n'
  after_fixture=$(fixture_inventory)
  after_target=$(object_state "$target")
  [[ "$after_fixture" == "$before_fixture" ]] || fail "$label: fixture changed"
  [[ "$after_target" == "$before_target" ]] || fail "$label: target changed"
}
assert_unsafe_path() {
  local label=$1 target=$2
  shift 2
  assert_unsafe_call "$label" "$target" call_path_env "$@" "$UNSAFE_PROJECT" "$UNSAFE_SESSION"
}

PATH_FIXTURE="$TMP_TEST/path-fixture"
CALL_CWD="$PATH_FIXTURE/cwd"
mkdir -p "$PATH_FIXTURE/h-physical" "$PATH_FIXTURE/xdg" "$PATH_FIXTURE/tmp" "$CALL_CWD"
ln -s h-physical "$PATH_FIXTURE/h-parent"
HARNESS_ROOT="$PATH_FIXTURE/h-parent/root"
HARNESS_PHYSICAL="$PATH_FIXTURE/h-physical/root"
HARNESS_PROJECTS=("harness-$NAME_SUFFIX" "harness-two-$NAME_SUFFIX")
HARNESS_SESSIONS=("session-$NAME_SUFFIX" "session-two-$NAME_SUFFIX")
XDG_CANDIDATE="$PATH_FIXTURE/xdg/aosp-harness-$EUID"
TMP_CANDIDATE="$PATH_FIXTURE/tmp/aosp-harness-$EUID"
xdg_before=$(object_state "$XDG_CANDIDATE")
tmp_before=$(object_state "$TMP_CANDIDATE")
for project in "${HARNESS_PROJECTS[@]}"; do
  for session in "${HARNESS_SESSIONS[@]}"; do
    assert_call 0 'path HARNESS isolation' "$HARNESS_PHYSICAL/$project/$session"$'\n' '' call_path_env set "$HARNESS_ROOT" set "$PATH_FIXTURE/xdg" set "$PATH_FIXTURE/tmp" "$project" "$session"
    assert_fresh_dir "$HARNESS_PHYSICAL/$project/$session" 'path HARNESS isolation'
  done
  assert_fresh_dir "$HARNESS_PHYSICAL/$project" 'path HARNESS isolation'
done
assert_fresh_dir "$HARNESS_PHYSICAL" 'path HARNESS isolation'
[[ $(object_state "$XDG_CANDIDATE") == "$xdg_before" ]] || fail 'path HARNESS precedence: XDG candidate changed'
[[ $(object_state "$TMP_CANDIDATE") == "$tmp_before" ]] || fail 'path HARNESS precedence: TMP candidate changed'
for dispatcher_case in '' 'path' 'path project' 'path project session extra' 'other project session' 'path . session' 'path project ..'; do
  read -r -a dispatcher_args <<<"$dispatcher_case"
  HARNESS_STATE_ROOT=$HARNESS_ROOT assert_call 2 "dispatcher unsafe: $dispatcher_case" '' $'error: unsafe session state\n' _harness_session_state_run "${dispatcher_args[@]}"
done
HARNESS_STATE_ROOT=$HARNESS_ROOT assert_call 0 'dispatcher success' "$HARNESS_PHYSICAL/${HARNESS_PROJECTS[0]}/${HARNESS_SESSIONS[0]}"$'\n' '' _harness_session_state_run path "${HARNESS_PROJECTS[0]}" "${HARNESS_SESSIONS[0]}"
FAULT_PROVIDER="$TMP_TEST/session-state-fault.sh"
FAULT_ROOT="$PATH_FIXTURE/fault-root"
sed 's/os.mkdir(name, 0o700, dir_fd=parent_fd)/raise OSError(errno.EIO, "injected")/' "$PROVIDER" >"$FAULT_PROVIDER"
for private_name in _harness_session_state_foundation_path _harness_session_state_run; do
  private_args=("${HARNESS_PROJECTS[0]}" "${HARNESS_SESSIONS[0]}")
  [[ "$private_name" == _harness_session_state_run ]] && private_args=(path "${HARNESS_PROJECTS[0]}" "${HARNESS_SESSIONS[0]}")
  HARNESS_STATE_ROOT=$FAULT_ROOT PROVIDER=$FAULT_PROVIDER assert_call 1 "$private_name operation failure" '' $'error: session state operation failed\n' bash -c 'source "$PROVIDER"; "$@"' bash "$private_name" "${private_args[@]}"
done
XDG_PROJECT="xdg-$NAME_SUFFIX"
XDG_SESSION="session-$NAME_SUFFIX"
XDG_ROOT=$(cd "$PATH_FIXTURE/xdg" && pwd -P)/aosp-harness-$EUID
tmp_before=$(object_state "$TMP_CANDIDATE")
assert_call 0 'path XDG selection' "$XDG_ROOT/$XDG_PROJECT/$XDG_SESSION"$'\n' '' call_path_env unset '' set "$PATH_FIXTURE/xdg" set "$PATH_FIXTURE/tmp" "$XDG_PROJECT" "$XDG_SESSION"
[[ $(object_state "$TMP_CANDIDATE") == "$tmp_before" ]] || fail 'path XDG selection: TMP candidate changed'
TMP_PROJECT="tmp-$NAME_SUFFIX"
TMP_SESSION="session-$NAME_SUFFIX"
TMP_ROOT=$(cd "$PATH_FIXTURE/tmp" && pwd -P)/aosp-harness-$EUID
assert_call 0 'path TMP selection' "$TMP_ROOT/$TMP_PROJECT/$TMP_SESSION"$'\n' '' call_path_env unset '' unset '' set "$PATH_FIXTURE/tmp" "$TMP_PROJECT" "$TMP_SESSION"
if (( DEFAULT_ROOT_EXISTED == 0 )); then
  mkdir -m 700 "$DEFAULT_ROOT"
fi
DEFAULT_FIXTURE_INODE=$(stat -c '%i' "$DEFAULT_ROOT")
DEFAULT_PROJECT="default-$NAME_SUFFIX"
DEFAULT_SESSION="session-$NAME_SUFFIX"
EMPTY_TMP_PROJECT="empty-tmp-$NAME_SUFFIX"
EMPTY_TMP_SESSION="session-$NAME_SUFFIX"
DEFAULT_PATHS+=("$DEFAULT_PROJECT/$DEFAULT_SESSION" "$EMPTY_TMP_PROJECT/$EMPTY_TMP_SESSION")
assert_call 0 'path default selection' "$DEFAULT_ROOT/$DEFAULT_PROJECT/$DEFAULT_SESSION"$'\n' '' call_path_env unset '' unset '' unset '' "$DEFAULT_PROJECT" "$DEFAULT_SESSION"
assert_call 0 'path empty TMP selection' "$DEFAULT_ROOT/$EMPTY_TMP_PROJECT/$EMPTY_TMP_SESSION"$'\n' '' call_path_env unset '' unset '' set '' "$EMPTY_TMP_PROJECT" "$EMPTY_TMP_SESSION"
[[ $(stat -c '%i' "$DEFAULT_ROOT") == "$DEFAULT_FIXTURE_INODE" ]] || fail 'path default selection: preexisting root inode changed'

INVALID_ROOT="$PATH_FIXTURE/invalid-root"
UNSAFE_PROJECT="unsafe-$NAME_SUFFIX"
UNSAFE_SESSION="session-$NAME_SUFFIX"
assert_unsafe_call 'path arity zero' "$INVALID_ROOT" call_path_env set "$INVALID_ROOT" unset '' unset ''
assert_unsafe_call 'path arity one' "$INVALID_ROOT" call_path_env set "$INVALID_ROOT" unset '' unset '' "$UNSAFE_PROJECT"
assert_unsafe_call 'path arity extra' "$INVALID_ROOT" call_path_env set "$INVALID_ROOT" unset '' unset '' "$UNSAFE_PROJECT" "$UNSAFE_SESSION" extra
for ids in '. session' 'project ..' '-project session' 'project bad/session' 'project bad\\session' 'project bad session'; do
  read -r project session extra <<<"$ids"
  [[ -z "${extra:-}" ]] || session="$session $extra"
  assert_unsafe_call 'path invalid id' "$INVALID_ROOT" call_path_env set "$INVALID_ROOT" unset '' unset '' "$project" "$session"
done

mkdir "$PATH_FIXTURE/dot-parent"
assert_unsafe_path 'path HARNESS empty' "$PATH_FIXTURE/unused" set '' unset '' unset ''
assert_unsafe_path 'path HARNESS relative' "$CALL_CWD/relative" set relative unset '' unset ''
assert_unsafe_path 'path HARNESS dot component' "$PATH_FIXTURE/dot-root" set "$PATH_FIXTURE/dot-parent/../dot-root" unset '' unset ''
assert_unsafe_path 'path HARNESS control' "$PATH_FIXTURE/newline" set "$PATH_FIXTURE/"$'new\nline' unset '' unset ''
assert_unsafe_path 'path HARNESS missing parent' "$PATH_FIXTURE/missing/root" set "$PATH_FIXTURE/missing/root" unset '' unset ''
assert_unsafe_path 'path HARNESS slash' "/$UNSAFE_PROJECT" set / unset '' unset ''

assert_unsafe_path 'path XDG empty' "$PATH_FIXTURE/aosp-harness-$EUID" unset '' set '' unset ''
assert_unsafe_path 'path XDG relative' "$CALL_CWD/relative/aosp-harness-$EUID" unset '' set relative unset ''
assert_unsafe_path 'path XDG dot component' "$PATH_FIXTURE/dot-root/aosp-harness-$EUID" unset '' set "$PATH_FIXTURE/dot-parent/../dot-root" unset ''
assert_unsafe_path 'path XDG control' "$PATH_FIXTURE/newline/aosp-harness-$EUID" unset '' set "$PATH_FIXTURE/"$'new\nline' unset ''
assert_unsafe_path 'path XDG missing base' "$PATH_FIXTURE/missing-xdg/aosp-harness-$EUID" unset '' set "$PATH_FIXTURE/missing-xdg" unset ''

assert_unsafe_path 'path TMP relative' "$CALL_CWD/relative/aosp-harness-$EUID" unset '' unset '' set relative
assert_unsafe_path 'path TMP dot component' "$PATH_FIXTURE/dot-root/aosp-harness-$EUID" unset '' unset '' set "$PATH_FIXTURE/dot-parent/../dot-root"
assert_unsafe_path 'path TMP control' "$PATH_FIXTURE/newline/aosp-harness-$EUID" unset '' unset '' set "$PATH_FIXTURE/"$'new\nline'
assert_unsafe_path 'path TMP missing base' "$PATH_FIXTURE/missing-tmp/aosp-harness-$EUID" unset '' unset '' set "$PATH_FIXTURE/missing-tmp"

[[ -d "$DEFAULT_ROOT" && ! -L "$DEFAULT_ROOT" ]] || fail 'path default selection: preexisting root missing'
[[ $(stat -c '%i' "$DEFAULT_ROOT") == "$DEFAULT_FIXTURE_INODE" ]] || fail 'path default selection: preexisting root replaced'
if (( DEFAULT_ROOT_EXISTED == 1 )); then
  [[ $(stat -c '%i' "$DEFAULT_ROOT") == "$DEFAULT_ROOT_ORIGINAL_INODE" ]] || fail 'path default selection: original root inode changed'
fi

printf 'RESULT PASS  session state foundation\n'
