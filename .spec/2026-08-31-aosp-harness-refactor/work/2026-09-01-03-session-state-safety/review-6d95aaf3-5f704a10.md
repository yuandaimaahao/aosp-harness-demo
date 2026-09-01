# review 包 6d95aaf3..5f704a10

## commit 列表

```
5f704a1 refactor(session): publish private foundation module
```

## diff --stat

```
 ...ession-state.sh => session-state-foundation.sh} | 10 ++-
 ...n-state.sh => test-session-state-foundation.sh} | 79 ++++++++++++++--------
 2 files changed, 58 insertions(+), 31 deletions(-)
```

## diff

```diff
diff --git a/common/.harness/lib/session-state.sh b/common/.harness/lib/session-state-foundation.sh
similarity index 92%
rename from common/.harness/lib/session-state.sh
rename to common/.harness/lib/session-state-foundation.sh
index 4daed58..45d3a7f 100644
--- a/common/.harness/lib/session-state.sh
+++ b/common/.harness/lib/session-state-foundation.sh
@@ -8,20 +8,28 @@ _harness_component_is_safe() {
 }
 
 harness_validate_feature_name() {
   [[ $# == 1 ]] && _harness_component_is_safe "$1" || {
     printf '%s\n' 'error: invalid feature name' >&2
     return 2
   }
 }
 
 _harness_session_state_run() (
+  if [[ $# != 3 ]]; then
+    printf '%s\n' 'error: unsafe session state' >&2
+    return 2
+  fi
+  if [[ $1 != path ]] || ! _harness_component_is_safe "$2" || ! _harness_component_is_safe "$3"; then
+    printf '%s\n' 'error: unsafe session state' >&2
+    return 2
+  fi
   umask 077
   python3 - "$@" <<'PY'
 import errno, os, pathlib, stat, sys
 class UnsafeState(Exception): pass
 class OperationFailure(Exception): pass
 OPEN_DIR = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
 
 def _checked_path(value, reject_root=False):
     if (not value or not os.path.isabs(value)
             or any(ord(char) < 32 or ord(char) == 127 for char in value)
@@ -102,17 +110,17 @@ try:
     print(_dispatch_path(sys.argv[2], sys.argv[3]))
 except UnsafeState:
     print("error: unsafe session state", file=sys.stderr)
     raise SystemExit(2)
 except (OSError, OperationFailure):
     print("error: session state operation failed", file=sys.stderr)
     raise SystemExit(1)
 PY
 )
 
-harness_session_state_path() {
+_harness_session_state_foundation_path() {
   if [[ $# != 2 ]] || ! _harness_component_is_safe "$1" || ! _harness_component_is_safe "$2"; then
     printf '%s\n' 'error: unsafe session state' >&2
     return 2
   fi
   _harness_session_state_run path "$1" "$2"
 }
diff --git a/tests/test-session-state.sh b/tests/test-session-state-foundation.sh
similarity index 71%
rename from tests/test-session-state.sh
rename to tests/test-session-state-foundation.sh
index fe4299b..64597e0 100755
--- a/tests/test-session-state.sh
+++ b/tests/test-session-state-foundation.sh
@@ -1,15 +1,15 @@
 #!/usr/bin/env bash
 set -u
 
 ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
-PROVIDER=${PROVIDER:-"$ROOT/common/.harness/lib/session-state.sh"}
+PROVIDER=${PROVIDER:-"$ROOT/common/.harness/lib/session-state-foundation.sh"}
 DEFAULT_ROOT="/tmp/aosp-harness-$EUID"
 
 # Make the preexisting-empty-root case deterministic. The outer invocation owns
 # only the inode it creates; the inner full test must preserve that inode.
 if [[ ${HARNESS_TEST_DEFAULT_CHILD:-0} == 0 && ! -e "$DEFAULT_ROOT" && ! -L "$DEFAULT_ROOT" ]]; then
   mkdir -m 700 "$DEFAULT_ROOT"
   wrapper_inode=$(stat -c '%i' "$DEFAULT_ROOT")
   HARNESS_TEST_DEFAULT_CHILD=1 bash "${BASH_SOURCE[0]}"
   wrapper_rc=$?
   wrapper_error=
@@ -60,45 +60,58 @@ capture_api() {
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
-
+assert_call() {
+  local expected_rc=$1 label=$2 expected_out=$3 expected_err=$4
+  shift 4
+  capture_api "$@"
+  assert_api "$expected_rc" "$label" "$expected_out" "$expected_err"
+}
 [[ -f "$PROVIDER" ]] || fail 'validate valid: provider missing'
+unset HARNESS_SESSION_STATE_PROVIDER_VERSION
+export HARNESS_STATE_ROOT='./source-harness-sentinel' XDG_RUNTIME_DIR='./source-xdg-sentinel' TMPDIR='./source-tmp-sentinel'
+source_sentinel_before=$(declare -p HARNESS_STATE_ROOT XDG_RUNTIME_DIR TMPDIR)
 # shellcheck source=/dev/null
 source "$PROVIDER" || fail 'validate valid: source failed'
+source_sentinel_after=$(declare -p HARNESS_STATE_ROOT XDG_RUNTIME_DIR TMPDIR)
+[[ "$source_sentinel_after" == "$source_sentinel_before" ]] || fail 'source sentinel: declarations changed'
+unset HARNESS_STATE_ROOT XDG_RUNTIME_DIR TMPDIR
 
+for public_name in harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove; do
+  if declare -F "$public_name" >/dev/null; then
+    fail "public surface: $public_name must be absent"
+  fi
+done
+declare -F harness_validate_feature_name >/dev/null || fail 'public surface: validate missing'
+declare -F _harness_session_state_foundation_path >/dev/null || fail 'private surface: foundation path missing'
+declare -F _harness_session_state_run >/dev/null || fail 'private surface: dispatcher missing'
+[[ ! -v HARNESS_SESSION_STATE_PROVIDER_VERSION ]] || fail 'public surface: provider marker must be absent'
 valid_1=$(printf 'a')
 valid_128=$(printf 'a%.0s' {1..128})
-capture_api harness_validate_feature_name 'a._-Z9'
-assert_api 0 'validate punctuation valid' '' ''
-capture_api harness_validate_feature_name "$valid_1"
-assert_api 0 'validate valid' '' ''
-capture_api harness_validate_feature_name "$valid_128"
-assert_api 0 'validate 128-byte' '' ''
+assert_call 0 'validate punctuation valid' '' '' harness_validate_feature_name 'a._-Z9'
+assert_call 0 'validate valid' '' '' harness_validate_feature_name "$valid_1"
+assert_call 0 'validate 128-byte' '' '' harness_validate_feature_name "$valid_128"
 
 invalid_names=('' '.' '..' '-a' 'a/b' 'a\\b' 'a b' $'a\nb' 'é' "${valid_128}a")
 for name in "${invalid_names[@]}"; do
-  capture_api harness_validate_feature_name "$name"
-  assert_api 2 'validate invalid' '' $'error: invalid feature name\n'
+  assert_call 2 'validate invalid' '' $'error: invalid feature name\n' harness_validate_feature_name "$name"
 done
 
-capture_api harness_validate_feature_name
-assert_api 2 'validate arity zero' '' $'error: invalid feature name\n'
-capture_api harness_validate_feature_name a b
-assert_api 2 'validate arity extra' '' $'error: invalid feature name\n'
-
+assert_call 2 'validate arity zero' '' $'error: invalid feature name\n' harness_validate_feature_name
+assert_call 2 'validate arity extra' '' $'error: invalid feature name\n' harness_validate_feature_name a b
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
@@ -107,35 +120,32 @@ source_err=$(mktemp "$TMP_TEST/source-err.XXXXXX")
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
-
 # The predicate explicitly pins byte-oriented matching to the C locale.
 grep -Fq 'LC_ALL=C' "$PROVIDER" || fail 'validate locale: C locale missing'
 
-declare -F harness_session_state_path >/dev/null || fail 'path HARNESS precedence: function missing'
-
 call_path_env() (
   local harness_set=$1 harness_value=$2 xdg_set=$3 xdg_value=$4 tmp_set=$5 tmp_value=$6
   shift 6
   cd "$CALL_CWD" || exit 1
   unset HARNESS_STATE_ROOT XDG_RUNTIME_DIR TMPDIR
   [[ "$harness_set" == set ]] && export HARNESS_STATE_ROOT=$harness_value
   [[ "$xdg_set" == set ]] && export XDG_RUNTIME_DIR=$xdg_value
   [[ "$tmp_set" == set ]] && export TMPDIR=$tmp_value
-  harness_session_state_path "$@"
+  _harness_session_state_foundation_path "$@"
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
@@ -172,61 +182,70 @@ CALL_CWD="$PATH_FIXTURE/cwd"
 mkdir -p "$PATH_FIXTURE/h-physical" "$PATH_FIXTURE/xdg" "$PATH_FIXTURE/tmp" "$CALL_CWD"
 ln -s h-physical "$PATH_FIXTURE/h-parent"
 HARNESS_ROOT="$PATH_FIXTURE/h-parent/root"
 HARNESS_PHYSICAL="$PATH_FIXTURE/h-physical/root"
 HARNESS_PROJECT="harness-$NAME_SUFFIX"
 HARNESS_SESSION="session-$NAME_SUFFIX"
 XDG_CANDIDATE="$PATH_FIXTURE/xdg/aosp-harness-$EUID"
 TMP_CANDIDATE="$PATH_FIXTURE/tmp/aosp-harness-$EUID"
 xdg_before=$(object_state "$XDG_CANDIDATE")
 tmp_before=$(object_state "$TMP_CANDIDATE")
-capture_api call_path_env set "$HARNESS_ROOT" set "$PATH_FIXTURE/xdg" set "$PATH_FIXTURE/tmp" "$HARNESS_PROJECT" "$HARNESS_SESSION"
-assert_api 0 'path HARNESS precedence' "$HARNESS_PHYSICAL/$HARNESS_PROJECT/$HARNESS_SESSION"$'\n' ''
+assert_call 0 'path HARNESS precedence' "$HARNESS_PHYSICAL/$HARNESS_PROJECT/$HARNESS_SESSION"$'\n' '' call_path_env set "$HARNESS_ROOT" set "$PATH_FIXTURE/xdg" set "$PATH_FIXTURE/tmp" "$HARNESS_PROJECT" "$HARNESS_SESSION"
 [[ $(object_state "$XDG_CANDIDATE") == "$xdg_before" ]] || fail 'path HARNESS precedence: XDG candidate changed'
 [[ $(object_state "$TMP_CANDIDATE") == "$tmp_before" ]] || fail 'path HARNESS precedence: TMP candidate changed'
 for path in "$HARNESS_PHYSICAL" "$HARNESS_PHYSICAL/$HARNESS_PROJECT" "$HARNESS_PHYSICAL/$HARNESS_PROJECT/$HARNESS_SESSION"; do
   assert_fresh_dir "$path" 'path HARNESS fresh'
 done
+for dispatcher_case in '' 'path' 'path project' 'path project session extra' 'other project session' 'path . session' 'path project ..'; do
+  read -r -a dispatcher_args <<<"$dispatcher_case"
+  HARNESS_STATE_ROOT=$HARNESS_ROOT assert_call 2 "dispatcher unsafe: $dispatcher_case" '' $'error: unsafe session state\n' _harness_session_state_run "${dispatcher_args[@]}"
+done
+HARNESS_STATE_ROOT=$HARNESS_ROOT assert_call 0 'dispatcher success' "$HARNESS_PHYSICAL/$HARNESS_PROJECT/$HARNESS_SESSION"$'\n' '' _harness_session_state_run path "$HARNESS_PROJECT" "$HARNESS_SESSION"
+FAULT_PROVIDER="$TMP_TEST/session-state-fault.sh"
+FAULT_ROOT="$PATH_FIXTURE/fault-root"
+sed 's/os.mkdir(name, 0o700, dir_fd=parent_fd)/raise OperationFailure/' "$PROVIDER" >"$FAULT_PROVIDER"
+for private_name in _harness_session_state_foundation_path _harness_session_state_run; do
+  private_args=("$HARNESS_PROJECT" "$HARNESS_SESSION")
+  [[ "$private_name" == _harness_session_state_run ]] && private_args=(path "$HARNESS_PROJECT" "$HARNESS_SESSION")
+  HARNESS_STATE_ROOT=$FAULT_ROOT PROVIDER=$FAULT_PROVIDER assert_call 1 "$private_name operation failure" '' $'error: session state operation failed\n' bash -c 'source "$PROVIDER"; "$@"' bash "$private_name" "${private_args[@]}"
+done
 
 XDG_PROJECT="xdg-$NAME_SUFFIX"
 XDG_SESSION="session-$NAME_SUFFIX"
 XDG_ROOT=$(cd "$PATH_FIXTURE/xdg" && pwd -P)/aosp-harness-$EUID
 tmp_before=$(object_state "$TMP_CANDIDATE")
-capture_api call_path_env unset '' set "$PATH_FIXTURE/xdg" set "$PATH_FIXTURE/tmp" "$XDG_PROJECT" "$XDG_SESSION"
-assert_api 0 'path XDG selection' "$XDG_ROOT/$XDG_PROJECT/$XDG_SESSION"$'\n' ''
+assert_call 0 'path XDG selection' "$XDG_ROOT/$XDG_PROJECT/$XDG_SESSION"$'\n' '' call_path_env unset '' set "$PATH_FIXTURE/xdg" set "$PATH_FIXTURE/tmp" "$XDG_PROJECT" "$XDG_SESSION"
 [[ $(object_state "$TMP_CANDIDATE") == "$tmp_before" ]] || fail 'path XDG selection: TMP candidate changed'
 
 TMP_PROJECT="tmp-$NAME_SUFFIX"
 TMP_SESSION="session-$NAME_SUFFIX"
 TMP_ROOT=$(cd "$PATH_FIXTURE/tmp" && pwd -P)/aosp-harness-$EUID
-capture_api call_path_env unset '' unset '' set "$PATH_FIXTURE/tmp" "$TMP_PROJECT" "$TMP_SESSION"
-assert_api 0 'path TMP selection' "$TMP_ROOT/$TMP_PROJECT/$TMP_SESSION"$'\n' ''
+assert_call 0 'path TMP selection' "$TMP_ROOT/$TMP_PROJECT/$TMP_SESSION"$'\n' '' call_path_env unset '' unset '' set "$PATH_FIXTURE/tmp" "$TMP_PROJECT" "$TMP_SESSION"
 
 if (( DEFAULT_ROOT_EXISTED == 0 )); then
   mkdir -m 700 "$DEFAULT_ROOT"
 fi
 DEFAULT_FIXTURE_INODE=$(stat -c '%i' "$DEFAULT_ROOT")
 DEFAULT_PROJECT="default-$NAME_SUFFIX"
 DEFAULT_SESSION="session-$NAME_SUFFIX"
 EMPTY_TMP_PROJECT="empty-tmp-$NAME_SUFFIX"
 EMPTY_TMP_SESSION="session-$NAME_SUFFIX"
 DEFAULT_PATHS+=("$DEFAULT_PROJECT/$DEFAULT_SESSION" "$EMPTY_TMP_PROJECT/$EMPTY_TMP_SESSION")
-capture_api call_path_env unset '' unset '' unset '' "$DEFAULT_PROJECT" "$DEFAULT_SESSION"
-assert_api 0 'path default selection' "$DEFAULT_ROOT/$DEFAULT_PROJECT/$DEFAULT_SESSION"$'\n' ''
-capture_api call_path_env unset '' unset '' set '' "$EMPTY_TMP_PROJECT" "$EMPTY_TMP_SESSION"
-assert_api 0 'path empty TMP selection' "$DEFAULT_ROOT/$EMPTY_TMP_PROJECT/$EMPTY_TMP_SESSION"$'\n' ''
+assert_call 0 'path default selection' "$DEFAULT_ROOT/$DEFAULT_PROJECT/$DEFAULT_SESSION"$'\n' '' call_path_env unset '' unset '' unset '' "$DEFAULT_PROJECT" "$DEFAULT_SESSION"
+assert_call 0 'path empty TMP selection' "$DEFAULT_ROOT/$EMPTY_TMP_PROJECT/$EMPTY_TMP_SESSION"$'\n' '' call_path_env unset '' unset '' set '' "$EMPTY_TMP_PROJECT" "$EMPTY_TMP_SESSION"
 [[ $(stat -c '%i' "$DEFAULT_ROOT") == "$DEFAULT_FIXTURE_INODE" ]] || fail 'path default selection: preexisting root inode changed'
 
 INVALID_ROOT="$PATH_FIXTURE/invalid-root"
 UNSAFE_PROJECT="unsafe-$NAME_SUFFIX"
 UNSAFE_SESSION="session-$NAME_SUFFIX"
 assert_unsafe_call 'path arity zero' "$INVALID_ROOT" call_path_env set "$INVALID_ROOT" unset '' unset ''
+assert_unsafe_call 'path arity one' "$INVALID_ROOT" call_path_env set "$INVALID_ROOT" unset '' unset '' "$UNSAFE_PROJECT"
 assert_unsafe_call 'path arity extra' "$INVALID_ROOT" call_path_env set "$INVALID_ROOT" unset '' unset '' "$UNSAFE_PROJECT" "$UNSAFE_SESSION" extra
 for ids in '. session' 'project ..' '-project session' 'project bad/session' 'project bad\\session' 'project bad session'; do
   read -r project session extra <<<"$ids"
   [[ -z "${extra:-}" ]] || session="$session $extra"
   assert_unsafe_call 'path invalid id' "$INVALID_ROOT" call_path_env set "$INVALID_ROOT" unset '' unset '' "$project" "$session"
 done
 
 mkdir "$PATH_FIXTURE/dot-parent"
 assert_unsafe_path 'path HARNESS empty' "$PATH_FIXTURE/unused" set '' unset '' unset ''
 assert_unsafe_path 'path HARNESS relative' "$CALL_CWD/relative" set relative unset '' unset ''
@@ -245,11 +264,11 @@ assert_unsafe_path 'path TMP relative' "$CALL_CWD/relative/aosp-harness-$EUID" u
 assert_unsafe_path 'path TMP dot component' "$PATH_FIXTURE/dot-root/aosp-harness-$EUID" unset '' unset '' set "$PATH_FIXTURE/dot-parent/../dot-root"
 assert_unsafe_path 'path TMP control' "$PATH_FIXTURE/newline/aosp-harness-$EUID" unset '' unset '' set "$PATH_FIXTURE/"$'new\nline'
 assert_unsafe_path 'path TMP missing base' "$PATH_FIXTURE/missing-tmp/aosp-harness-$EUID" unset '' unset '' set "$PATH_FIXTURE/missing-tmp"
 
 [[ -d "$DEFAULT_ROOT" && ! -L "$DEFAULT_ROOT" ]] || fail 'path default selection: preexisting root missing'
 [[ $(stat -c '%i' "$DEFAULT_ROOT") == "$DEFAULT_FIXTURE_INODE" ]] || fail 'path default selection: preexisting root replaced'
 if (( DEFAULT_ROOT_EXISTED == 1 )); then
   [[ $(stat -c '%i' "$DEFAULT_ROOT") == "$DEFAULT_ROOT_ORIGINAL_INODE" ]] || fail 'path default selection: original root inode changed'
 fi
 
-printf 'RESULT PASS  session state\n'
+printf 'RESULT PASS  session state foundation\n'
```
