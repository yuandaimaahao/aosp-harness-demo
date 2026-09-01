# review 包 4d78b423..ac985df3

## commit 列表

```
ac985df test(session): cover project session isolation
```

## diff --stat

```
 tests/test-session-state-foundation.sh | 25 +++++++++++++------------
 1 file changed, 13 insertions(+), 12 deletions(-)
```

## diff

```diff
diff --git a/tests/test-session-state-foundation.sh b/tests/test-session-state-foundation.sh
index 02c1922..d3497fa 100755
--- a/tests/test-session-state-foundation.sh
+++ b/tests/test-session-state-foundation.sh
@@ -175,58 +175,59 @@ assert_unsafe_path() {
   shift 2
   assert_unsafe_call "$label" "$target" call_path_env "$@" "$UNSAFE_PROJECT" "$UNSAFE_SESSION"
 }
 
 PATH_FIXTURE="$TMP_TEST/path-fixture"
 CALL_CWD="$PATH_FIXTURE/cwd"
 mkdir -p "$PATH_FIXTURE/h-physical" "$PATH_FIXTURE/xdg" "$PATH_FIXTURE/tmp" "$CALL_CWD"
 ln -s h-physical "$PATH_FIXTURE/h-parent"
 HARNESS_ROOT="$PATH_FIXTURE/h-parent/root"
 HARNESS_PHYSICAL="$PATH_FIXTURE/h-physical/root"
-HARNESS_PROJECT="harness-$NAME_SUFFIX"
-HARNESS_SESSION="session-$NAME_SUFFIX"
+HARNESS_PROJECTS=("harness-$NAME_SUFFIX" "harness-two-$NAME_SUFFIX")
+HARNESS_SESSIONS=("session-$NAME_SUFFIX" "session-two-$NAME_SUFFIX")
 XDG_CANDIDATE="$PATH_FIXTURE/xdg/aosp-harness-$EUID"
 TMP_CANDIDATE="$PATH_FIXTURE/tmp/aosp-harness-$EUID"
 xdg_before=$(object_state "$XDG_CANDIDATE")
 tmp_before=$(object_state "$TMP_CANDIDATE")
-assert_call 0 'path HARNESS precedence' "$HARNESS_PHYSICAL/$HARNESS_PROJECT/$HARNESS_SESSION"$'\n' '' call_path_env set "$HARNESS_ROOT" set "$PATH_FIXTURE/xdg" set "$PATH_FIXTURE/tmp" "$HARNESS_PROJECT" "$HARNESS_SESSION"
+for project in "${HARNESS_PROJECTS[@]}"; do
+  for session in "${HARNESS_SESSIONS[@]}"; do
+    assert_call 0 'path HARNESS isolation' "$HARNESS_PHYSICAL/$project/$session"$'\n' '' call_path_env set "$HARNESS_ROOT" set "$PATH_FIXTURE/xdg" set "$PATH_FIXTURE/tmp" "$project" "$session"
+    assert_fresh_dir "$HARNESS_PHYSICAL/$project/$session" 'path HARNESS isolation'
+  done
+  assert_fresh_dir "$HARNESS_PHYSICAL/$project" 'path HARNESS isolation'
+done
+assert_fresh_dir "$HARNESS_PHYSICAL" 'path HARNESS isolation'
 [[ $(object_state "$XDG_CANDIDATE") == "$xdg_before" ]] || fail 'path HARNESS precedence: XDG candidate changed'
 [[ $(object_state "$TMP_CANDIDATE") == "$tmp_before" ]] || fail 'path HARNESS precedence: TMP candidate changed'
-for path in "$HARNESS_PHYSICAL" "$HARNESS_PHYSICAL/$HARNESS_PROJECT" "$HARNESS_PHYSICAL/$HARNESS_PROJECT/$HARNESS_SESSION"; do
-  assert_fresh_dir "$path" 'path HARNESS fresh'
-done
 for dispatcher_case in '' 'path' 'path project' 'path project session extra' 'other project session' 'path . session' 'path project ..'; do
   read -r -a dispatcher_args <<<"$dispatcher_case"
   HARNESS_STATE_ROOT=$HARNESS_ROOT assert_call 2 "dispatcher unsafe: $dispatcher_case" '' $'error: unsafe session state\n' _harness_session_state_run "${dispatcher_args[@]}"
 done
-HARNESS_STATE_ROOT=$HARNESS_ROOT assert_call 0 'dispatcher success' "$HARNESS_PHYSICAL/$HARNESS_PROJECT/$HARNESS_SESSION"$'\n' '' _harness_session_state_run path "$HARNESS_PROJECT" "$HARNESS_SESSION"
+HARNESS_STATE_ROOT=$HARNESS_ROOT assert_call 0 'dispatcher success' "$HARNESS_PHYSICAL/${HARNESS_PROJECTS[0]}/${HARNESS_SESSIONS[0]}"$'\n' '' _harness_session_state_run path "${HARNESS_PROJECTS[0]}" "${HARNESS_SESSIONS[0]}"
 FAULT_PROVIDER="$TMP_TEST/session-state-fault.sh"
 FAULT_ROOT="$PATH_FIXTURE/fault-root"
 sed 's/os.mkdir(name, 0o700, dir_fd=parent_fd)/raise OSError(errno.EIO, "injected")/' "$PROVIDER" >"$FAULT_PROVIDER"
 for private_name in _harness_session_state_foundation_path _harness_session_state_run; do
-  private_args=("$HARNESS_PROJECT" "$HARNESS_SESSION")
-  [[ "$private_name" == _harness_session_state_run ]] && private_args=(path "$HARNESS_PROJECT" "$HARNESS_SESSION")
+  private_args=("${HARNESS_PROJECTS[0]}" "${HARNESS_SESSIONS[0]}")
+  [[ "$private_name" == _harness_session_state_run ]] && private_args=(path "${HARNESS_PROJECTS[0]}" "${HARNESS_SESSIONS[0]}")
   HARNESS_STATE_ROOT=$FAULT_ROOT PROVIDER=$FAULT_PROVIDER assert_call 1 "$private_name operation failure" '' $'error: session state operation failed\n' bash -c 'source "$PROVIDER"; "$@"' bash "$private_name" "${private_args[@]}"
 done
-
 XDG_PROJECT="xdg-$NAME_SUFFIX"
 XDG_SESSION="session-$NAME_SUFFIX"
 XDG_ROOT=$(cd "$PATH_FIXTURE/xdg" && pwd -P)/aosp-harness-$EUID
 tmp_before=$(object_state "$TMP_CANDIDATE")
 assert_call 0 'path XDG selection' "$XDG_ROOT/$XDG_PROJECT/$XDG_SESSION"$'\n' '' call_path_env unset '' set "$PATH_FIXTURE/xdg" set "$PATH_FIXTURE/tmp" "$XDG_PROJECT" "$XDG_SESSION"
 [[ $(object_state "$TMP_CANDIDATE") == "$tmp_before" ]] || fail 'path XDG selection: TMP candidate changed'
-
 TMP_PROJECT="tmp-$NAME_SUFFIX"
 TMP_SESSION="session-$NAME_SUFFIX"
 TMP_ROOT=$(cd "$PATH_FIXTURE/tmp" && pwd -P)/aosp-harness-$EUID
 assert_call 0 'path TMP selection' "$TMP_ROOT/$TMP_PROJECT/$TMP_SESSION"$'\n' '' call_path_env unset '' unset '' set "$PATH_FIXTURE/tmp" "$TMP_PROJECT" "$TMP_SESSION"
-
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
```
