# review 包 37cdf6df..bbdc50d6

## commit 列表

```
bbdc50d test(session): pin mutation object signatures
```

## diff --stat

```
 tests/test-session-path.sh | 20 ++++++++++----------
 1 file changed, 10 insertions(+), 10 deletions(-)
```

## diff

```diff
diff --git a/tests/test-session-path.sh b/tests/test-session-path.sh
index bc8d264..d246c25 100755
--- a/tests/test-session-path.sh
+++ b/tests/test-session-path.sh
@@ -48,60 +48,60 @@ PY
       link=-; hash=-; [[ -L $root/$relative ]] && link=$(readlink "$root/$relative"); [[ -f $root/$relative && ! -L $root/$relative ]] && hash=$(sha256sum "$root/$relative" | awk '{print $1}')
       stat -c "$relative|%F|%D|%i|%a|$link|$hash" "$root/$relative"
     done < <(find "$root" -mindepth 1 -printf '%P\n' | LC_ALL=C sort)
   }
   expect_scope() {
     local root=$1 expected=$2 actual; actual=$(scoped_inventory "$root")
     [[ $(printf '%s\n' "$actual" | cut -d'|' -f1) == "$(printf '%s\n' "$expected" | LC_ALL=C sort)" && $(printf '%s\n' "$actual" | awk -F'|' '$1=="provider.sh"') == "$PROVIDER_BEFORE" ]] || fail "scope ${root##*/}: unexpected object or provider mutation"
   }
   mutate_invoke() {
     local copy=$1 root=$2; PROVIDER_BEFORE=$(scoped_inventory "${copy%/*}" | awk -F'|' '$1=="provider.sh"')
-    capture env -u XDG_RUNTIME_DIR -u TMPDIR HARNESS_STATE_ROOT="$root" bash -c 'source "$1"; source "$2"; _harness_session_path_core project session' _ "$FOUNDATION" "$copy"
-  }
-  managed='    pass  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN'
-  catch_line='            pass  # provider-copy catch sentinel is injected here'
+    capture env -u XDG_RUNTIME_DIR -u TMPDIR HARNESS_STATE_ROOT="$root" bash -c 'source "$1"; source "$2"; _harness_session_path_core project session' _ "$FOUNDATION" "$copy"; }
+  managed='    pass  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN'; catch_line='            pass  # provider-copy catch sentinel is injected here'
+  empty_regular() { [[ -f $1 && ! -L $1 && ! -s $1 && $(stat -c %a "$1") == 600 ]]; }
   for kind in dir link file; do
     base="$TMP_TEST/swap-$kind"; mkdir "$base"; mkdir -m 700 "$base/state"; printf sentinel >"$base/state/victim"
     copy="$base/provider.sh"; copy_provider "$copy"; hit="$base/hit"; old_meta=$(stat -c '%D|%i|%a' "$base/state"); old_victim=$(scoped_inventory "$base" | awk -F'|' '$1=="state/victim"' | cut -d'|' -f2-)
     case $kind in
       dir) action="os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.mkdir(name, 0o700, dir_fd=parent_fd)";;
       link) action="os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.symlink('state.old', name, dir_fd=parent_fd)";;
       file) action="os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.close(os.open(name, os.O_CREAT|os.O_WRONLY, 0o600, dir_fd=parent_fd))";;
     esac
     replace_once "$copy" "$managed" "    if phase == 'before_open' and name == 'state' and not made: $action; pathlib.Path('$hit').touch()  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
     mutate_invoke "$copy" "$base/state"; expect "swap $kind" 2 '' $'error: unsafe session state\n'
     expect_scope "$base" "$(printf '%s\n' hit provider.sh state state.old state.old/victim)"; current_meta=$(stat -c '%D|%i|%a' "$base/state")
-    case $kind in dir) [[ -d $base/state && ! -L $base/state && ${current_meta##*|} == 700 ]];; link) [[ -L $base/state && $(readlink "$base/state") == state.old ]];; file) [[ -f $base/state && ! -L $base/state && ${current_meta##*|} == 600 ]];; esac || fail "swap $kind: replacement"
-    [[ -e $hit && ${current_meta%|*} != ${old_meta%|*} && $old_meta == "$(stat -c '%D|%i|%a' "$base/state.old")" && $old_victim == "$(scoped_inventory "$base" | awk -F'|' '$1=="state.old/victim"' | cut -d'|' -f2-)" && ! -e $base/state/project && ! -e $base/state.old/project ]] || fail "swap $kind: victim or traversal"
+    case $kind in dir) [[ -d $base/state && ! -L $base/state && ${current_meta##*|} == 700 ]];; link) [[ -L $base/state && $(readlink "$base/state") == state.old ]];; file) [[ -f $base/state && ! -L $base/state && ${current_meta##*|} == 600 && $(sha256sum "$base/state" | awk '{print $1}') == e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 ]];; esac || fail "swap $kind: replacement"
+    empty_regular "$hit" && [[ ${current_meta%|*} != ${old_meta%|*} && $old_meta == "$(stat -c '%D|%i|%a' "$base/state.old")" && $old_victim == "$(scoped_inventory "$base" | awk -F'|' '$1=="state.old/victim"' | cut -d'|' -f2-)" && ! -e $base/state/project && ! -e $base/state.old/project ]] || fail "swap $kind: victim or traversal"
   done
   for kind in safe unsafe disappear; do
     base="$TMP_TEST/eexist-$kind"; mkdir "$base"; copy="$base/provider.sh"; copy_provider "$copy"; hit="$base/hit"; caught="$base/caught"
     if [[ $kind == disappear ]]; then action="if name == 'state' and not made: (os.mkdir(name, 0o700, dir_fd=parent_fd), pathlib.Path('$hit').touch()) if phase == 'before_mkdir' else (os.rmdir(name, dir_fd=parent_fd), pathlib.Path('$base/gone').touch()) if phase == 'after_eexist' else None"
     else action="if phase == 'before_mkdir' and name == 'state' and not made: os.mkdir(name, 0o700, dir_fd=parent_fd); pathlib.Path('$hit').touch()"; [[ $kind == safe ]] || action="$action; os.chmod(name, 0o755, dir_fd=parent_fd)"; fi
     replace_once "$copy" "$managed" "    $action  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
     replace_once "$copy" "$catch_line" "            pathlib.Path('$caught').touch()  # provider-copy catch sentinel is injected here"
     mutate_invoke "$copy" "$base/state"
     case $kind in safe) expected=0; out="$base/state/project/session"$'\n'; err=''; scope=$'caught\nhit\nprovider.sh\nstate\nstate/project\nstate/project/session';; unsafe) expected=2; out=''; err=$'error: unsafe session state\n'; scope=$'caught\nhit\nprovider.sh\nstate';; disappear) expected=1; out=''; err=$'error: session state operation failed\n'; scope=$'caught\ngone\nhit\nprovider.sh';; esac
-    expect "eexist $kind" "$expected" "$out" "$err"; expect_scope "$base" "$scope"; [[ -e $hit && -e $caught && ( $kind != disappear || -e $base/gone && ! -e $base/state ) ]] || fail "eexist $kind: injection missed"
-    [[ $kind != unsafe || $(stat -c %a "$base/state") == 755 && ! -e $base/state/project ]] || fail 'eexist unsafe: winner modified'
+    expect "eexist $kind" "$expected" "$out" "$err"; expect_scope "$base" "$scope"
+    empty_regular "$hit" && empty_regular "$caught" && { [[ $kind != disappear ]] || { empty_regular "$base/gone" && [[ ! -e $base/state ]]; }; } || fail "eexist $kind: injection missed"
+    [[ $kind != unsafe || -d $base/state && ! -L $base/state && $(stat -c %a "$base/state") == 755 && ! -e $base/state/project ]] || fail 'eexist unsafe: winner modified'
   done
   base="$TMP_TEST/mkdir-replace"; mkdir "$base"; copy="$base/provider.sh"; copy_provider "$copy"; hit="$base/hit"
   replace_once "$copy" "$managed" "    if phase == 'before_open' and name == 'state' and made: os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.mkdir(name, 0o700, dir_fd=parent_fd); os.chmod(name, 0o755, dir_fd=parent_fd); pathlib.Path('$hit').touch()  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
   mutate_invoke "$copy" "$base/state"; expect 'mkdir replacement' 2 '' $'error: unsafe session state\n'
-  expect_scope "$base" "$(printf '%s\n' hit provider.sh state state.old)"; [[ -e $hit && $(stat -c %D:%i "$base/state") != "$(stat -c %D:%i "$base/state.old")" && $(stat -c %a "$base/state") == 755 && $(stat -c %a "$base/state.old") == 700 && ! -e $base/state/project ]] || fail 'mkdir replacement modified'
+  expect_scope "$base" "$(printf '%s\n' hit provider.sh state state.old)"; empty_regular "$hit" && [[ -d $base/state && ! -L $base/state && $(stat -c %D:%i "$base/state") != "$(stat -c %D:%i "$base/state.old")" && $(stat -c %a "$base/state") == 755 && $(stat -c %a "$base/state.old") == 700 && ! -e $base/state/project ]] || fail 'mkdir replacement modified'
   base="$TMP_TEST/mkdir-error"; mkdir "$base"; copy="$base/provider.sh"; copy_provider "$copy"; replace_once "$copy" '            os.mkdir(name, 0o700, dir_fd=parent_fd)' "            raise FileNotFoundError(errno.ENOENT, 'gone')"
   mutate_invoke "$copy" "$base/state"; expect 'mkdir ordinary error' 1 '' $'error: session state operation failed\n'; expect_scope "$base" provider.sh
   for kind in owner eio; do
     base="$TMP_TEST/$kind"; mkdir "$base"; copy="$base/provider.sh"; copy_provider "$copy"
     if [[ $kind == owner ]]; then replace_once "$copy" '    expected_euid = os.geteuid()  # HARNESS_TEST_MARKER_EXPECTED_EUID' "    expected_euid = os.geteuid() + (name == 'state'); pathlib.Path('$base/hit').touch()  # HARNESS_TEST_MARKER_EXPECTED_EUID"; expected=2; err=$'error: unsafe session state\n'; scope=$'hit\nprovider.sh\nstate'
     else replace_once "$copy" '        pass  # HARNESS_TEST_MARKER_OS_ERROR' '        raise OSError(errno.EIO)  # HARNESS_TEST_MARKER_OS_ERROR'; expected=1; err=$'error: session state operation failed\n'; scope=provider.sh; fi
-    mutate_invoke "$copy" "$base/state"; expect "$kind" "$expected" '' "$err"; expect_scope "$base" "$scope"; [[ $kind != owner || -e $base/hit && ! -e $base/state/project ]] || fail 'owner injection missed'
+    mutate_invoke "$copy" "$base/state"; expect "$kind" "$expected" '' "$err"; expect_scope "$base" "$scope"; [[ $kind != owner ]] || { empty_regular "$base/hit" && [[ ! -e $base/state/project ]]; } || fail 'owner injection missed'
   done
   for phase in before_mkdir after_eexist before_open; do [[ $(grep -Fo "_managed_checkpoint(\"$phase\"" "$PROVIDER" | wc -l) == 1 ]] || fail "phase $phase count"; done
   ! grep -q fchmod "$PROVIDER" || fail 'forbidden fchmod'
   printf 'RESULT PASS  session path safety\n'; exit 0
 fi
 if [[ $GROUP == roots-static ]]; then
   mkdir "$TMP_TEST/harness" "$TMP_TEST/xdg" "$TMP_TEST/tmp" "$TMP_TEST/physical"
   ln -s "$TMP_TEST/physical" "$TMP_TEST/logical"
   printf sentinel >"$TMP_TEST/xdg/sentinel"; printf sentinel >"$TMP_TEST/tmp/sentinel"
   lower_before=$(find "$TMP_TEST/xdg" "$TMP_TEST/tmp" -printf '%p|%y|%m|%s\n' | LC_ALL=C sort)
```
