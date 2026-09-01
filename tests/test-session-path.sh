#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FOUNDATION="$ROOT/common/.harness/lib/session-state-foundation.sh"
PROVIDER="$ROOT/common/.harness/lib/session-state-path.sh"
TMP_TEST=$(mktemp -d "${TMPDIR:-/tmp}/session-path-test.XXXXXX")
cleanup() {
  [[ -z ${DEFAULT_PROJECT_PATH:-} ]] || rmdir "$DEFAULT_PROJECT_PATH/s" "$DEFAULT_PROJECT_PATH" 2>/dev/null || :
  [[ ${DEFAULT_ROOT_CREATED:-0} != 1 ]] || rmdir "$DEFAULT_ROOT" 2>/dev/null || :
  rm -rf "$TMP_TEST"
}
trap cleanup EXIT
fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}
SUMMARY='RESULT PASS  session path safety'
pass() { printf '%s\n' "$SUMMARY"; }
case ${1:-all} in
  --case)
    [[ $# == 2 ]] || fail 'option: expected --case name'
    GROUP=$2
    [[ $GROUP == source-validate || $GROUP == roots-static ]] || fail "option: unsupported case $GROUP"
    ;;
  --dependency-absent)
    [[ $# == 1 ]] || fail 'option: --dependency-absent takes no value'
    GROUP=dependency-absent
    ;;
  all)
    (($# <= 1)) || fail 'option: all takes no value'
    GROUP=all
    ;;
  *) fail "option: ${1:-empty} unsupported" ;;
esac
[[ -f "$PROVIDER" ]] || fail 'source present: provider missing'
[[ -f "$FOUNDATION" ]] || {
  [[ $GROUP == all || $GROUP == dependency-absent ]] || fail 'source present: foundation missing'
  GROUP=dependency-absent
}
if [[ $GROUP == all ]]; then
  printf '%s\n' "$SUMMARY" >"$TMP_TEST/child-expected"
  for child in source-validate roots-static; do
    bash "${BASH_SOURCE[0]}" --case "$child" >"$TMP_TEST/child-out" 2>"$TMP_TEST/child-err"
    child_rc=$?
    [[ $child_rc == 0 && ! -s "$TMP_TEST/child-err" ]] && cmp -s "$TMP_TEST/child-out" "$TMP_TEST/child-expected" || fail "default $child: streams or rc"
  done
  git -C "$ROOT" diff --quiet d68911bde93f72d1e42dc85fba6271159e945170 HEAD -- common/.harness/lib/session-state-foundation.sh tests/test-session-state-foundation.sh || fail 'foundation files changed'
  pass
  exit 0
fi
if [[ $GROUP == roots-static ]]; then
  capture() {
    : >"$TMP_TEST/out"
    : >"$TMP_TEST/err"
    "$@" >"$TMP_TEST/out" 2>"$TMP_TEST/err"
    RC=$?
  }
  invoke() {
    local project=$2 session=$3
    shift 3
    capture env "$@" bash -c 'source "$1"; source "$2"; _harness_session_path_core "$3" "$4"' \
      _ "$FOUNDATION" "$PROVIDER" "$project" "$session"
  }
  expect() {
    local label=$1 rc=$2 out=$3 err=$4
    [[ $RC == "$rc" ]] || fail "$label: rc $RC"
    cmp -s "$TMP_TEST/out" <(printf %s "$out") || fail "$label: stdout"
    cmp -s "$TMP_TEST/err" <(printf %s "$err") || fail "$label: stderr"
  }
fi
check_structure() {
  managed_body=$(awk '/^def open_managed\(/{inside=1} /^def dispatch\(/{inside=0} inside' "$PROVIDER")
  for spec in 'MANAGED HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN' 'EXPECTED_EUID HARNESS_TEST_MARKER_EXPECTED_EUID' 'OS_ERROR HARNESS_TEST_MARKER_OS_ERROR'; do
    read -r label marker <<<"$spec"
    count=$(grep -Fo "$marker" "$PROVIDER" | wc -l)
    [[ $count == 1 ]] || fail "marker $label count: expected 1 got $count"
  done
  for phase in before_mkdir after_eexist before_open; do
    needle="_managed_checkpoint(\"$phase\""
    [[ $(grep -Fo "$needle" "$PROVIDER" | wc -l) == 1 && $(grep -Fo "$needle" <<<"$managed_body" | wc -l) == 1 ]] || fail "phase $phase global or managed-body count"
  done
  ! grep -q fchmod "$PROVIDER" || fail 'forbidden fchmod'
}
[[ $GROUP == dependency-absent ]] || check_structure
if [[ $GROUP == roots-static ]]; then
  mkdir "$TMP_TEST/harness" "$TMP_TEST/xdg" "$TMP_TEST/tmp" "$TMP_TEST/physical"
  ln -s "$TMP_TEST/physical" "$TMP_TEST/logical"
  printf sentinel >"$TMP_TEST/xdg/sentinel"
  printf sentinel >"$TMP_TEST/tmp/sentinel"
  lower_before=$(find "$TMP_TEST/xdg" "$TMP_TEST/tmp" -printf '%p|%y|%m|%s\n' | LC_ALL=C sort)
  invoke harness p s HARNESS_STATE_ROOT="$TMP_TEST/harness/state" XDG_RUNTIME_DIR="$TMP_TEST/xdg" TMPDIR="$TMP_TEST/tmp"
  [[ $RC != 1 ]] || ! cmp -s "$TMP_TEST/err" <(printf 'error: session state operation failed\n') || fail 'root HARNESS: python path engine missing'
  expect 'root HARNESS' 0 "$TMP_TEST/harness/state/p/s"$'\n' ''
  [[ $lower_before == "$(find "$TMP_TEST/xdg" "$TMP_TEST/tmp" -printf '%p|%y|%m|%s\n' | LC_ALL=C sort)" ]] || fail 'root HARNESS: lower priority changed'
  tmp_before=$(find "$TMP_TEST/tmp" -printf '%P|%y|%m|%s\n' | LC_ALL=C sort)
  invoke xdg p s -u HARNESS_STATE_ROOT XDG_RUNTIME_DIR="$TMP_TEST/xdg" TMPDIR="$TMP_TEST/tmp"
  expect 'root XDG' 0 "$TMP_TEST/xdg/aosp-harness-$(id -u)/p/s"$'\n' ''
  [[ $tmp_before == "$(find "$TMP_TEST/tmp" -printf '%P|%y|%m|%s\n' | LC_ALL=C sort)" ]] || fail 'root XDG: lower priority changed'
  invoke tmp p s -u HARNESS_STATE_ROOT -u XDG_RUNTIME_DIR TMPDIR="$TMP_TEST/tmp"
  expect 'root TMP' 0 "$TMP_TEST/tmp/aosp-harness-$(id -u)/p/s"$'\n' ''
  default_project="path-default-$$"
  DEFAULT_ROOT="/tmp/aosp-harness-$(id -u)"
  DEFAULT_PROJECT_PATH="$DEFAULT_ROOT/$default_project"
  [[ -e $DEFAULT_ROOT || -L $DEFAULT_ROOT ]] && DEFAULT_ROOT_CREATED=0 || DEFAULT_ROOT_CREATED=1
  invoke default "$default_project" s -u HARNESS_STATE_ROOT -u XDG_RUNTIME_DIR -u TMPDIR
  expect 'root default' 0 "$DEFAULT_PROJECT_PATH/s"$'\n' ''
  invoke physical p s HARNESS_STATE_ROOT="$TMP_TEST/logical/state"
  expect 'root physical' 0 "$TMP_TEST/physical/state/p/s"$'\n' ''
  mkdir "$TMP_TEST/fault" "$TMP_TEST/post-mkdir"
  printf '%s\n' 'import os' '_mkdir = os.mkdir' 'def vanish(path, mode=511, *, dir_fd=None):' \
    '    result = _mkdir(path, mode, dir_fd=dir_fd)' '    if path == "state": os.rmdir(path, dir_fd=dir_fd)' \
    '    return result' 'os.mkdir = vanish' >"$TMP_TEST/fault/sitecustomize.py"
  invoke post-mkdir p s PYTHONPATH="$TMP_TEST/fault" HARNESS_STATE_ROOT="$TMP_TEST/post-mkdir/state"
  expect 'post-mkdir disappear' 1 '' $'error: session state operation failed\n'
  for spec in \
    'harness|empty|' 'harness|relative|relative' "harness|control|$TMP_TEST/"$'\n'bad "harness|dot|$TMP_TEST/../bad" 'harness|slash|/' "harness|missing|$TMP_TEST/missing-h/state" \
    'xdg|empty|' 'xdg|relative|relative' "xdg|control|$TMP_TEST/"$'\n'bad "xdg|dot|$TMP_TEST/../bad" "xdg|missing|$TMP_TEST/missing-x" \
    'tmp|relative|relative' "tmp|control|$TMP_TEST/"$'\n'bad "tmp|dot|$TMP_TEST/../bad" "tmp|missing|$TMP_TEST/missing-t"; do
    source=${spec%%|*}
    rest=${spec#*|}
    label="$source-${rest%%|*}"
    value=${rest#*|}
    case $source in
      harness) root_env=(HARNESS_STATE_ROOT="$value" XDG_RUNTIME_DIR="$TMP_TEST/xdg" TMPDIR="$TMP_TEST/tmp") ;;
      xdg) root_env=(-u HARNESS_STATE_ROOT XDG_RUNTIME_DIR="$value" TMPDIR="$TMP_TEST/tmp") ;;
      tmp) root_env=(-u HARNESS_STATE_ROOT -u XDG_RUNTIME_DIR TMPDIR="$value") ;;
    esac
    before=$(find "$TMP_TEST" ! -path "$TMP_TEST/out" ! -path "$TMP_TEST/err" -printf '%P|%y|%D|%i|%m|%s\n' | LC_ALL=C sort)
    invoke "$label" p s "${root_env[@]}"
    expect "$label" 2 '' $'error: unsafe session state\n'
    [[ $before == "$(find "$TMP_TEST" ! -path "$TMP_TEST/out" ! -path "$TMP_TEST/err" -printf '%P|%y|%D|%i|%m|%s\n' | LC_ALL=C sort)" ]] || fail "$label: created state"
  done
  mkdir "$TMP_TEST/isolation"
  for project in p1 p2; do for session in s1 s2; do
    invoke isolation "$project" "$session" HARNESS_STATE_ROOT="$TMP_TEST/isolation/state"
    expect "isolation $project/$session" 0 "$TMP_TEST/isolation/state/$project/$session"$'\n' ''
  done; done
  expected=$(printf '%s\n' state state/p1 state/p2 state/p1/s1 state/p1/s2 state/p2/s1 state/p2/s2)
  actual=$(find "$TMP_TEST/isolation" -mindepth 1 -type d -printf '%P\n' | LC_ALL=C sort)
  [[ $(printf '%s\n' "$actual" | wc -l) == 7 && $actual == "$(printf %s "$expected" | LC_ALL=C sort)" ]] || fail 'isolation: exact seven directories'
  while IFS= read -r relative; do
    path="$TMP_TEST/isolation/$relative"
    [[ -d $path && ! -L $path && $(stat -c %u:%a "$path") == "$(id -u):700" ]] || fail "isolation unsafe: $relative"
  done <<<"$expected"
  for kind in link file mode; do for layer in root project session; do
    base="$TMP_TEST/static-$kind-$layer"
    mkdir "$base"
    root="$base/state"
    target=$root
    [[ $layer == root ]] || {
      mkdir -m 700 "$root"
      target="$root/project"
    }
    [[ $layer != session ]] || {
      mkdir -m 700 "$target"
      target="$target/session"
    }
    case $kind in
      link)
        mkdir "$base/victim"
        printf sentinel >"$base/victim/sentinel"
        ln -s "$base/victim" "$target"
        victim_before=$(stat -c '%D|%i|%a' "$base/victim")
        victim_hash=$(sha256sum "$base/victim/sentinel")
        ;;
      file) printf sentinel >"$target" ;;
      mode) mkdir -m 755 "$target" ;;
    esac
    before=$(find "$base" -printf '%P|%y|%l|%D|%i|%m|%s\n' | LC_ALL=C sort)
    invoke static project session HARNESS_STATE_ROOT="$root"
    expect "static $kind/$layer" 2 '' $'error: unsafe session state\n'
    [[ $before == "$(find "$base" -printf '%P|%y|%l|%D|%i|%m|%s\n' | LC_ALL=C sort)" ]] || fail "static $kind/$layer: inventory changed"
    [[ $kind != link || $victim_before == "$(stat -c '%D|%i|%a' "$base/victim")" && $victim_hash == "$(sha256sum "$base/victim/sentinel")" ]] || fail "static link/$layer: victim changed"
  done; done
  pass
  exit 0
fi
if [[ $GROUP == source-validate && ${HARNESS_TEST_SELF_CHECK:-0} == 0 ]]; then
  HARNESS_TEST_SELF_CHECK=1 HARNESS_TEST_FORCE_SOURCE_FAIL=none \
    bash "${BASH_SOURCE[0]}" --case source-validate >"$TMP_TEST/self-out" 2>"$TMP_TEST/self-err"
  self_rc=$?
  [[ $self_rc != 0 ]] || fail 'self-disproof: source fixture failure was masked'
fi
source_case() {
  local missing=$1 expected=$2 label=$3 audit="$TMP_TEST/$3-audit" watch="$TMP_TEST/$3-watch"
  mkdir "$audit" "$watch"
  printf sentinel >"$watch/sentinel"
  MISSING=$missing EXPECTED=$expected FOUNDATION=$FOUNDATION PROVIDER=$PROVIDER AUDIT=$audit WATCH=$watch bash <<'SH'
set -u
fail() { printf 'FAIL %s\n' "$1" >&2; exit 1; }
if [[ $MISSING == all ]]; then
  unset -f _harness_component_is_safe harness_validate_feature_name _harness_session_state_foundation_path _harness_session_state_run 2>/dev/null || :
else
  source "$FOUNDATION"
  [[ $MISSING == none ]] || unset -f "$MISSING"
fi
unset HARNESS_SESSION_STATE_PROVIDER_VERSION
unset -f _harness_session_path_core harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove 2>/dev/null || :
export HARNESS_STATE_ROOT="$WATCH/bad-harness" XDG_RUNTIME_DIR="$WATCH/bad-xdg" TMPDIR="$WATCH/bad-tmp"
snapshot() {
  local phase=$1
  declare -p HARNESS_STATE_ROOT XDG_RUNTIME_DIR TMPDIR >"$AUDIT/env-$phase"
  for name in _harness_component_is_safe harness_validate_feature_name _harness_session_state_foundation_path _harness_session_state_run; do declare -F "$name" >/dev/null && declare -f "$name"; done >"$AUDIT/functions-$phase"
  declare -F | awk '{print $3}' | LC_ALL=C sort >"$AUDIT/names-$phase"
  find "$WATCH" -mindepth 1 -printf '%P|%y|%D|%i|%m|%U|%s\n' | LC_ALL=C sort >"$AUDIT/inventory-$phase"
}
snapshot before
source "$PROVIDER" >"$AUDIT/out" 2>"$AUDIT/err"
rc=$?
snapshot after
[[ $rc == 0 && ! -s "$AUDIT/out" && ! -s "$AUDIT/err" ]] || fail 'source streams or rc'
cmp -s "$AUDIT/env-before" "$AUDIT/env-after" || fail 'source changed root declarations'
cmp -s "$AUDIT/functions-before" "$AUDIT/functions-after" || fail 'source changed foundation functions'
cmp -s "$AUDIT/inventory-before" "$AUDIT/inventory-after" && [[ $(<"$WATCH/sentinel") == sentinel ]] || fail 'source changed fixture'
[[ ! -v HARNESS_SESSION_STATE_PROVIDER_VERSION ]] || fail 'source set provider marker'
for name in harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove; do
  ! declare -F "$name" >/dev/null || fail "source defined public $name"
done
cp "$AUDIT/names-before" "$AUDIT/names-expected"
[[ $EXPECTED != present ]] || { printf '%s\n' _harness_session_path_core >>"$AUDIT/names-expected"; LC_ALL=C sort -o "$AUDIT/names-expected" "$AUDIT/names-expected"; }
cmp -s "$AUDIT/names-expected" "$AUDIT/names-after" || fail 'source changed exact function surface'
if [[ $EXPECTED == present ]]; then
  declare -F _harness_session_path_core >/dev/null || fail 'source did not define core'
else
  ! declare -F _harness_session_path_core >/dev/null || fail 'source defined core without dependency'
fi
[[ ${HARNESS_TEST_FORCE_SOURCE_FAIL:-} != "$MISSING" ]] || fail 'injected source fixture failure'
SH
}
if [[ $GROUP == dependency-absent ]]; then
  source_case all absent all-missing || exit $?
  pass
  exit 0
fi
for spec in 'none present present' 'harness_validate_feature_name absent missing-validate' '_harness_session_state_foundation_path absent missing-path' '_harness_session_state_run absent missing-run'; do
  read -r missing expected label <<<"$spec"
  source_case "$missing" "$expected" "$label" || exit $?
done
# shellcheck source=/dev/null
source "$FOUNDATION"
VALIDATE_LOG="$TMP_TEST/validate.log"
PYTHON_LOG="$TMP_TEST/python.log"
FAKE_BIN="$TMP_TEST/bin"
mkdir "$FAKE_BIN" "$TMP_TEST/core-watch"
printf '#!/usr/bin/env bash\nprintf called >>"$PYTHON_LOG"\n' >"$FAKE_BIN/python3"
chmod +x "$FAKE_BIN/python3"
harness_validate_feature_name() {
  printf '%s\n' "${1-}" >>"$VALIDATE_LOG"
  [[ $# == 1 && $1 != session-ok ]] || {
    printf 'validation detail must be discarded\n' >&2
    return 77
  }
}
# shellcheck source=/dev/null
source "$PROVIDER"
capture_core() {
  : >"$TMP_TEST/out"
  : >"$TMP_TEST/err"
  PATH="$FAKE_BIN:$PATH" PYTHON_LOG=$PYTHON_LOG HARNESS_STATE_ROOT="$TMP_TEST/core-watch/root" \
    _harness_session_path_core "$@" >"$TMP_TEST/out" 2>"$TMP_TEST/err"
  CORE_RC=$?
}
assert_core() {
  capture_core "$@"
  [[ $CORE_RC == 2 && ! -s "$TMP_TEST/out" ]] || fail 'core validate: rc or stdout'
  cmp -s "$TMP_TEST/err" <(printf 'error: unsafe session state\n') || fail 'core validate: stderr'
}
assert_core
assert_core only-one
assert_core one two three
: >"$VALIDATE_LOG"
before=$(find "$TMP_TEST/core-watch" -mindepth 1 -printf '%P|%y|%i|%m|%s\n' | LC_ALL=C sort)
assert_core project-ok session-ok
after=$(find "$TMP_TEST/core-watch" -mindepth 1 -printf '%P|%y|%i|%m|%s\n' | LC_ALL=C sort)
cmp -s "$VALIDATE_LOG" <(printf 'project-ok\nsession-ok\n') || fail 'core validate: call order'
[[ ! -s "$PYTHON_LOG" ]] || fail 'core validate: python invoked'
[[ $before == "$after" ]] || fail 'core validate: fixture changed'
pass
