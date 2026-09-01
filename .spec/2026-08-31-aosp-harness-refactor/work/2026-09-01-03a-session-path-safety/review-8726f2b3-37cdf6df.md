# review 包 8726f2b3..37cdf6df

## commit 列表

```
37cdf6d fix(session): close race mutation review gaps
```

## diff --stat

```
 common/.harness/lib/session-state-path.sh |  2 +-
 tests/test-session-path.sh                | 49 +++++++++++++++++++------------
 2 files changed, 32 insertions(+), 19 deletions(-)
```

## diff

```diff
diff --git a/common/.harness/lib/session-state-path.sh b/common/.harness/lib/session-state-path.sh
index 4cf3aad..b859b2f 100644
--- a/common/.harness/lib/session-state-path.sh
+++ b/common/.harness/lib/session-state-path.sh
@@ -59,21 +59,21 @@ def open_managed(parent_fd, name):
             except OSError as exc:
                 raise OperationFailure from exc
         except FileExistsError:
             pass  # provider-copy catch sentinel is injected here
             _managed_checkpoint("after_eexist", parent_fd, name, made)
             try:
                 before = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
             except OSError as exc:
                 raise OperationFailure from exc
         except OSError as exc:
-            path_error(exc)
+            raise OperationFailure from exc
     except OSError as exc:
         path_error(exc)
     _managed_checkpoint("before_open", parent_fd, name, made)
     if not stat.S_ISDIR(before.st_mode): raise UnsafeState
     child_fd = None
     try:
         child_fd = os.open(name, OPEN_DIR, dir_fd=parent_fd); current = os.fstat(child_fd)
     except OSError as exc:
         if child_fd is not None: os.close(child_fd)
         managed_open_error(exc)
diff --git a/tests/test-session-path.sh b/tests/test-session-path.sh
index 49204e0..bc8d264 100755
--- a/tests/test-session-path.sh
+++ b/tests/test-session-path.sh
@@ -19,78 +19,91 @@ if [[ $GROUP == roots-static || $GROUP == mutations ]]; then
       _ "$FOUNDATION" "$PROVIDER" "$project" "$session"
   }
   expect() {
     local label=$1 rc=$2 out=$3 err=$4
     [[ $RC == "$rc" ]] || fail "$label: rc $RC"
     cmp -s "$TMP_TEST/out" <(printf %s "$out") || fail "$label: stdout"
     cmp -s "$TMP_TEST/err" <(printf %s "$err") || fail "$label: stderr"
   }
 fi
 if [[ $GROUP == mutations ]]; then
-  copy_provider() {
-    cp "$PROVIDER" "$1"
+  copy_provider() { cp "$PROVIDER" "$1"
     for spec in 'MANAGED HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN' 'EXPECTED_EUID HARNESS_TEST_MARKER_EXPECTED_EUID' 'OS_ERROR HARNESS_TEST_MARKER_OS_ERROR'; do
-      read -r label marker <<<"$spec"; count=$(grep -c "$marker" "$1" || :)
+      read -r label marker <<<"$spec"; count=$(grep -Fo "$marker" "$1" | wc -l)
       [[ $count == 1 ]] || fail "marker $label count: expected 1 got $count"
     done
   }
   replace_once() {
     local file=$1 needle=$2 replacement=$3
     [[ $(grep -F -c -- "$needle" "$file") == 1 ]] || fail 'mutation needle count'
     python3 - "$file" "$needle" "$replacement" <<'PY'
 import pathlib, sys
 path = pathlib.Path(sys.argv[1]); text = path.read_text()
 if text.count(sys.argv[2]) != 1: raise SystemExit(1)
 path.write_text(text.replace(sys.argv[2], sys.argv[3]))
 PY
   }
+  scoped_inventory() {
+    local root=$1 relative link hash
+    while IFS= read -r relative; do
+      link=-; hash=-; [[ -L $root/$relative ]] && link=$(readlink "$root/$relative"); [[ -f $root/$relative && ! -L $root/$relative ]] && hash=$(sha256sum "$root/$relative" | awk '{print $1}')
+      stat -c "$relative|%F|%D|%i|%a|$link|$hash" "$root/$relative"
+    done < <(find "$root" -mindepth 1 -printf '%P\n' | LC_ALL=C sort)
+  }
+  expect_scope() {
+    local root=$1 expected=$2 actual; actual=$(scoped_inventory "$root")
+    [[ $(printf '%s\n' "$actual" | cut -d'|' -f1) == "$(printf '%s\n' "$expected" | LC_ALL=C sort)" && $(printf '%s\n' "$actual" | awk -F'|' '$1=="provider.sh"') == "$PROVIDER_BEFORE" ]] || fail "scope ${root##*/}: unexpected object or provider mutation"
+  }
   mutate_invoke() {
-    local copy=$1 root=$2
-    capture env -u XDG_RUNTIME_DIR -u TMPDIR HARNESS_STATE_ROOT="$root" bash -c \
-      'source "$1"; source "$2"; _harness_session_path_core project session' _ "$FOUNDATION" "$copy"
+    local copy=$1 root=$2; PROVIDER_BEFORE=$(scoped_inventory "${copy%/*}" | awk -F'|' '$1=="provider.sh"')
+    capture env -u XDG_RUNTIME_DIR -u TMPDIR HARNESS_STATE_ROOT="$root" bash -c 'source "$1"; source "$2"; _harness_session_path_core project session' _ "$FOUNDATION" "$copy"
   }
   managed='    pass  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN'
   catch_line='            pass  # provider-copy catch sentinel is injected here'
   for kind in dir link file; do
     base="$TMP_TEST/swap-$kind"; mkdir "$base"; mkdir -m 700 "$base/state"; printf sentinel >"$base/state/victim"
-    copy="$base/provider.sh"; copy_provider "$copy"; hit="$base/hit"; old_meta=$(stat -c '%D|%i|%a' "$base/state"); old_hash=$(sha256sum "$base/state/victim" | awk '{print $1}')
+    copy="$base/provider.sh"; copy_provider "$copy"; hit="$base/hit"; old_meta=$(stat -c '%D|%i|%a' "$base/state"); old_victim=$(scoped_inventory "$base" | awk -F'|' '$1=="state/victim"' | cut -d'|' -f2-)
     case $kind in
       dir) action="os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.mkdir(name, 0o700, dir_fd=parent_fd)";;
       link) action="os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.symlink('state.old', name, dir_fd=parent_fd)";;
       file) action="os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.close(os.open(name, os.O_CREAT|os.O_WRONLY, 0o600, dir_fd=parent_fd))";;
     esac
-    replace_once "$copy" "$managed" "    if phase == 'before_open' and name == 'state': $action; pathlib.Path('$hit').touch()  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
+    replace_once "$copy" "$managed" "    if phase == 'before_open' and name == 'state' and not made: $action; pathlib.Path('$hit').touch()  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
     mutate_invoke "$copy" "$base/state"; expect "swap $kind" 2 '' $'error: unsafe session state\n'
-    [[ -e $hit && $old_meta == "$(stat -c '%D|%i|%a' "$base/state.old")" && $old_hash == "$(sha256sum "$base/state.old/victim" | awk '{print $1}')" && ! -e $base/state/project && ! -e $base/state.old/project ]] || fail "swap $kind: victim or traversal"
+    expect_scope "$base" "$(printf '%s\n' hit provider.sh state state.old state.old/victim)"; current_meta=$(stat -c '%D|%i|%a' "$base/state")
+    case $kind in dir) [[ -d $base/state && ! -L $base/state && ${current_meta##*|} == 700 ]];; link) [[ -L $base/state && $(readlink "$base/state") == state.old ]];; file) [[ -f $base/state && ! -L $base/state && ${current_meta##*|} == 600 ]];; esac || fail "swap $kind: replacement"
+    [[ -e $hit && ${current_meta%|*} != ${old_meta%|*} && $old_meta == "$(stat -c '%D|%i|%a' "$base/state.old")" && $old_victim == "$(scoped_inventory "$base" | awk -F'|' '$1=="state.old/victim"' | cut -d'|' -f2-)" && ! -e $base/state/project && ! -e $base/state.old/project ]] || fail "swap $kind: victim or traversal"
   done
   for kind in safe unsafe disappear; do
     base="$TMP_TEST/eexist-$kind"; mkdir "$base"; copy="$base/provider.sh"; copy_provider "$copy"; hit="$base/hit"; caught="$base/caught"
-    if [[ $kind == disappear ]]; then action="if name == 'state': (os.mkdir(name, 0o700, dir_fd=parent_fd), pathlib.Path('$hit').touch()) if phase == 'before_mkdir' else (os.rmdir(name, dir_fd=parent_fd), pathlib.Path('$base/gone').touch()) if phase == 'after_eexist' else None"
-    else action="if phase == 'before_mkdir' and name == 'state': os.mkdir(name, 0o700, dir_fd=parent_fd); pathlib.Path('$hit').touch()"; [[ $kind == safe ]] || action="$action; os.chmod(name, 0o755, dir_fd=parent_fd)"; fi
+    if [[ $kind == disappear ]]; then action="if name == 'state' and not made: (os.mkdir(name, 0o700, dir_fd=parent_fd), pathlib.Path('$hit').touch()) if phase == 'before_mkdir' else (os.rmdir(name, dir_fd=parent_fd), pathlib.Path('$base/gone').touch()) if phase == 'after_eexist' else None"
+    else action="if phase == 'before_mkdir' and name == 'state' and not made: os.mkdir(name, 0o700, dir_fd=parent_fd); pathlib.Path('$hit').touch()"; [[ $kind == safe ]] || action="$action; os.chmod(name, 0o755, dir_fd=parent_fd)"; fi
     replace_once "$copy" "$managed" "    $action  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
     replace_once "$copy" "$catch_line" "            pathlib.Path('$caught').touch()  # provider-copy catch sentinel is injected here"
     mutate_invoke "$copy" "$base/state"
-    case $kind in safe) expected=0; out="$base/state/project/session"$'\n'; err='';; unsafe) expected=2; out=''; err=$'error: unsafe session state\n';; disappear) expected=1; out=''; err=$'error: session state operation failed\n';; esac
-    expect "eexist $kind" "$expected" "$out" "$err"; [[ -e $hit && -e $caught && ( $kind != disappear || -e $base/gone && ! -e $base/state ) ]] || fail "eexist $kind: injection missed"
+    case $kind in safe) expected=0; out="$base/state/project/session"$'\n'; err=''; scope=$'caught\nhit\nprovider.sh\nstate\nstate/project\nstate/project/session';; unsafe) expected=2; out=''; err=$'error: unsafe session state\n'; scope=$'caught\nhit\nprovider.sh\nstate';; disappear) expected=1; out=''; err=$'error: session state operation failed\n'; scope=$'caught\ngone\nhit\nprovider.sh';; esac
+    expect "eexist $kind" "$expected" "$out" "$err"; expect_scope "$base" "$scope"; [[ -e $hit && -e $caught && ( $kind != disappear || -e $base/gone && ! -e $base/state ) ]] || fail "eexist $kind: injection missed"
     [[ $kind != unsafe || $(stat -c %a "$base/state") == 755 && ! -e $base/state/project ]] || fail 'eexist unsafe: winner modified'
   done
   base="$TMP_TEST/mkdir-replace"; mkdir "$base"; copy="$base/provider.sh"; copy_provider "$copy"; hit="$base/hit"
   replace_once "$copy" "$managed" "    if phase == 'before_open' and name == 'state' and made: os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.mkdir(name, 0o700, dir_fd=parent_fd); os.chmod(name, 0o755, dir_fd=parent_fd); pathlib.Path('$hit').touch()  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
   mutate_invoke "$copy" "$base/state"; expect 'mkdir replacement' 2 '' $'error: unsafe session state\n'
-  [[ -e $hit && $(stat -c %a "$base/state") == 755 && $(stat -c %a "$base/state.old") == 700 && ! -e $base/state/project ]] || fail 'mkdir replacement modified'
+  expect_scope "$base" "$(printf '%s\n' hit provider.sh state state.old)"; [[ -e $hit && $(stat -c %D:%i "$base/state") != "$(stat -c %D:%i "$base/state.old")" && $(stat -c %a "$base/state") == 755 && $(stat -c %a "$base/state.old") == 700 && ! -e $base/state/project ]] || fail 'mkdir replacement modified'
+  base="$TMP_TEST/mkdir-error"; mkdir "$base"; copy="$base/provider.sh"; copy_provider "$copy"; replace_once "$copy" '            os.mkdir(name, 0o700, dir_fd=parent_fd)' "            raise FileNotFoundError(errno.ENOENT, 'gone')"
+  mutate_invoke "$copy" "$base/state"; expect 'mkdir ordinary error' 1 '' $'error: session state operation failed\n'; expect_scope "$base" provider.sh
   for kind in owner eio; do
     base="$TMP_TEST/$kind"; mkdir "$base"; copy="$base/provider.sh"; copy_provider "$copy"
-    if [[ $kind == owner ]]; then replace_once "$copy" '    expected_euid = os.geteuid()  # HARNESS_TEST_MARKER_EXPECTED_EUID' "    expected_euid = os.geteuid() + (name == 'state'); pathlib.Path('$base/hit').touch()  # HARNESS_TEST_MARKER_EXPECTED_EUID"; expected=2; err=$'error: unsafe session state\n'
-    else replace_once "$copy" '        pass  # HARNESS_TEST_MARKER_OS_ERROR' '        raise OSError(errno.EIO)  # HARNESS_TEST_MARKER_OS_ERROR'; expected=1; err=$'error: session state operation failed\n'; fi
-    mutate_invoke "$copy" "$base/state"; expect "$kind" "$expected" '' "$err"; [[ $kind != owner || -e $base/hit && ! -e $base/state/project ]] || fail 'owner injection missed'
+    if [[ $kind == owner ]]; then replace_once "$copy" '    expected_euid = os.geteuid()  # HARNESS_TEST_MARKER_EXPECTED_EUID' "    expected_euid = os.geteuid() + (name == 'state'); pathlib.Path('$base/hit').touch()  # HARNESS_TEST_MARKER_EXPECTED_EUID"; expected=2; err=$'error: unsafe session state\n'; scope=$'hit\nprovider.sh\nstate'
+    else replace_once "$copy" '        pass  # HARNESS_TEST_MARKER_OS_ERROR' '        raise OSError(errno.EIO)  # HARNESS_TEST_MARKER_OS_ERROR'; expected=1; err=$'error: session state operation failed\n'; scope=provider.sh; fi
+    mutate_invoke "$copy" "$base/state"; expect "$kind" "$expected" '' "$err"; expect_scope "$base" "$scope"; [[ $kind != owner || -e $base/hit && ! -e $base/state/project ]] || fail 'owner injection missed'
   done
-  for phase in before_mkdir after_eexist before_open; do [[ $(grep -c "_managed_checkpoint(\"$phase\"" "$PROVIDER") == 1 ]] || fail "phase $phase count"; done
+  for phase in before_mkdir after_eexist before_open; do [[ $(grep -Fo "_managed_checkpoint(\"$phase\"" "$PROVIDER" | wc -l) == 1 ]] || fail "phase $phase count"; done
   ! grep -q fchmod "$PROVIDER" || fail 'forbidden fchmod'
   printf 'RESULT PASS  session path safety\n'; exit 0
 fi
 if [[ $GROUP == roots-static ]]; then
   mkdir "$TMP_TEST/harness" "$TMP_TEST/xdg" "$TMP_TEST/tmp" "$TMP_TEST/physical"
   ln -s "$TMP_TEST/physical" "$TMP_TEST/logical"
   printf sentinel >"$TMP_TEST/xdg/sentinel"; printf sentinel >"$TMP_TEST/tmp/sentinel"
   lower_before=$(find "$TMP_TEST/xdg" "$TMP_TEST/tmp" -printf '%p|%y|%m|%s\n' | LC_ALL=C sort)
   invoke harness p s HARNESS_STATE_ROOT="$TMP_TEST/harness/state" XDG_RUNTIME_DIR="$TMP_TEST/xdg" TMPDIR="$TMP_TEST/tmp"
   [[ $RC != 1 ]] || ! cmp -s "$TMP_TEST/err" <(printf 'error: session state operation failed\n') || fail 'root HARNESS: python path engine missing'
```
