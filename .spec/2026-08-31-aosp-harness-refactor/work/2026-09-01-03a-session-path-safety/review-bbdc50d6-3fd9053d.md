# review 包 bbdc50d6..3fd9053d

## commit 列表

```
3fd9053 test(session): fit path contract within quality gate
fad7bf3 test(session): close path safety contract
```

## diff --stat

```
 tests/test-session-path.sh | 236 +++++++++++++++++++++++++--------------------
 1 file changed, 129 insertions(+), 107 deletions(-)
```

## diff

```diff
diff --git a/tests/test-session-path.sh b/tests/test-session-path.sh
index d246c25..858cf60 100755
--- a/tests/test-session-path.sh
+++ b/tests/test-session-path.sh
@@ -1,194 +1,206 @@
 #!/usr/bin/env bash
 set -u
 ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
 FOUNDATION="$ROOT/common/.harness/lib/session-state-foundation.sh"
 PROVIDER="$ROOT/common/.harness/lib/session-state-path.sh"
 TMP_TEST=$(mktemp -d "${TMPDIR:-/tmp}/session-path-test.XXXXXX")
-trap 'rm -rf "$TMP_TEST"' EXIT
-fail() { printf 'FAIL %s\n' "$1" >&2; exit 1; }
-[[ ${1:-} == --case && $# == 2 ]] || fail 'option: expected --case name'
-GROUP=$2
-[[ $GROUP == source-validate || $GROUP == roots-static || $GROUP == mutations ]] || fail "option: unsupported case $GROUP"
-[[ -f "$FOUNDATION" ]] || fail 'source present: foundation missing'
+cleanup() {
+  [[ -z ${DEFAULT_PROJECT_PATH:-} ]] || rmdir "$DEFAULT_PROJECT_PATH/s" "$DEFAULT_PROJECT_PATH" 2>/dev/null || :
+  [[ ${DEFAULT_ROOT_CREATED:-0} != 1 ]] || rmdir "$DEFAULT_ROOT" 2>/dev/null || :
+  rm -rf "$TMP_TEST"
+}
+trap cleanup EXIT
+fail() {
+  printf 'FAIL %s\n' "$1" >&2
+  exit 1
+}
+SUMMARY='RESULT PASS  session path safety'
+pass() { printf '%s\n' "$SUMMARY"; }
+case ${1:-all} in
+  --case)
+    [[ $# == 2 ]] || fail 'option: expected --case name'
+    GROUP=$2
+    [[ $GROUP == source-validate || $GROUP == roots-static ]] || fail "option: unsupported case $GROUP"
+    ;;
+  --dependency-absent)
+    [[ $# == 1 ]] || fail 'option: --dependency-absent takes no value'
+    GROUP=dependency-absent
+    ;;
+  all)
+    (($# <= 1)) || fail 'option: all takes no value'
+    GROUP=all
+    ;;
+  *) fail "option: ${1:-empty} unsupported" ;;
+esac
 [[ -f "$PROVIDER" ]] || fail 'source present: provider missing'
-if [[ $GROUP == roots-static || $GROUP == mutations ]]; then
-  capture() { : >"$TMP_TEST/out"; : >"$TMP_TEST/err"; "$@" >"$TMP_TEST/out" 2>"$TMP_TEST/err"; RC=$?; }
+[[ -f "$FOUNDATION" ]] || {
+  [[ $GROUP == all || $GROUP == dependency-absent ]] || fail 'source present: foundation missing'
+  GROUP=dependency-absent
+}
+if [[ $GROUP == all ]]; then
+  printf '%s\n' "$SUMMARY" >"$TMP_TEST/child-expected"
+  for child in source-validate roots-static; do
+    bash "${BASH_SOURCE[0]}" --case "$child" >"$TMP_TEST/child-out" 2>"$TMP_TEST/child-err"
+    child_rc=$?
+    [[ $child_rc == 0 && ! -s "$TMP_TEST/child-err" ]] && cmp -s "$TMP_TEST/child-out" "$TMP_TEST/child-expected" || fail "default $child: streams or rc"
+  done
+  git -C "$ROOT" diff --quiet d68911bde93f72d1e42dc85fba6271159e945170 HEAD -- common/.harness/lib/session-state-foundation.sh tests/test-session-state-foundation.sh || fail 'foundation files changed'
+  pass
+  exit 0
+fi
+if [[ $GROUP == roots-static ]]; then
+  capture() {
+    : >"$TMP_TEST/out"
+    : >"$TMP_TEST/err"
+    "$@" >"$TMP_TEST/out" 2>"$TMP_TEST/err"
+    RC=$?
+  }
   invoke() {
-    local tag=$1 project=$2 session=$3; shift 3
+    local project=$2 session=$3
+    shift 3
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
-if [[ $GROUP == mutations ]]; then
-  copy_provider() { cp "$PROVIDER" "$1"
-    for spec in 'MANAGED HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN' 'EXPECTED_EUID HARNESS_TEST_MARKER_EXPECTED_EUID' 'OS_ERROR HARNESS_TEST_MARKER_OS_ERROR'; do
-      read -r label marker <<<"$spec"; count=$(grep -Fo "$marker" "$1" | wc -l)
-      [[ $count == 1 ]] || fail "marker $label count: expected 1 got $count"
-    done
-  }
-  replace_once() {
-    local file=$1 needle=$2 replacement=$3
-    [[ $(grep -F -c -- "$needle" "$file") == 1 ]] || fail 'mutation needle count'
-    python3 - "$file" "$needle" "$replacement" <<'PY'
-import pathlib, sys
-path = pathlib.Path(sys.argv[1]); text = path.read_text()
-if text.count(sys.argv[2]) != 1: raise SystemExit(1)
-path.write_text(text.replace(sys.argv[2], sys.argv[3]))
-PY
-  }
-  scoped_inventory() {
-    local root=$1 relative link hash
-    while IFS= read -r relative; do
-      link=-; hash=-; [[ -L $root/$relative ]] && link=$(readlink "$root/$relative"); [[ -f $root/$relative && ! -L $root/$relative ]] && hash=$(sha256sum "$root/$relative" | awk '{print $1}')
-      stat -c "$relative|%F|%D|%i|%a|$link|$hash" "$root/$relative"
-    done < <(find "$root" -mindepth 1 -printf '%P\n' | LC_ALL=C sort)
-  }
-  expect_scope() {
-    local root=$1 expected=$2 actual; actual=$(scoped_inventory "$root")
-    [[ $(printf '%s\n' "$actual" | cut -d'|' -f1) == "$(printf '%s\n' "$expected" | LC_ALL=C sort)" && $(printf '%s\n' "$actual" | awk -F'|' '$1=="provider.sh"') == "$PROVIDER_BEFORE" ]] || fail "scope ${root##*/}: unexpected object or provider mutation"
-  }
-  mutate_invoke() {
-    local copy=$1 root=$2; PROVIDER_BEFORE=$(scoped_inventory "${copy%/*}" | awk -F'|' '$1=="provider.sh"')
-    capture env -u XDG_RUNTIME_DIR -u TMPDIR HARNESS_STATE_ROOT="$root" bash -c 'source "$1"; source "$2"; _harness_session_path_core project session' _ "$FOUNDATION" "$copy"; }
-  managed='    pass  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN'; catch_line='            pass  # provider-copy catch sentinel is injected here'
-  empty_regular() { [[ -f $1 && ! -L $1 && ! -s $1 && $(stat -c %a "$1") == 600 ]]; }
-  for kind in dir link file; do
-    base="$TMP_TEST/swap-$kind"; mkdir "$base"; mkdir -m 700 "$base/state"; printf sentinel >"$base/state/victim"
-    copy="$base/provider.sh"; copy_provider "$copy"; hit="$base/hit"; old_meta=$(stat -c '%D|%i|%a' "$base/state"); old_victim=$(scoped_inventory "$base" | awk -F'|' '$1=="state/victim"' | cut -d'|' -f2-)
-    case $kind in
-      dir) action="os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.mkdir(name, 0o700, dir_fd=parent_fd)";;
-      link) action="os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.symlink('state.old', name, dir_fd=parent_fd)";;
-      file) action="os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.close(os.open(name, os.O_CREAT|os.O_WRONLY, 0o600, dir_fd=parent_fd))";;
-    esac
-    replace_once "$copy" "$managed" "    if phase == 'before_open' and name == 'state' and not made: $action; pathlib.Path('$hit').touch()  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
-    mutate_invoke "$copy" "$base/state"; expect "swap $kind" 2 '' $'error: unsafe session state\n'
-    expect_scope "$base" "$(printf '%s\n' hit provider.sh state state.old state.old/victim)"; current_meta=$(stat -c '%D|%i|%a' "$base/state")
-    case $kind in dir) [[ -d $base/state && ! -L $base/state && ${current_meta##*|} == 700 ]];; link) [[ -L $base/state && $(readlink "$base/state") == state.old ]];; file) [[ -f $base/state && ! -L $base/state && ${current_meta##*|} == 600 && $(sha256sum "$base/state" | awk '{print $1}') == e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 ]];; esac || fail "swap $kind: replacement"
-    empty_regular "$hit" && [[ ${current_meta%|*} != ${old_meta%|*} && $old_meta == "$(stat -c '%D|%i|%a' "$base/state.old")" && $old_victim == "$(scoped_inventory "$base" | awk -F'|' '$1=="state.old/victim"' | cut -d'|' -f2-)" && ! -e $base/state/project && ! -e $base/state.old/project ]] || fail "swap $kind: victim or traversal"
+check_structure() {
+  managed_body=$(awk '/^def open_managed\(/{inside=1} /^def dispatch\(/{inside=0} inside' "$PROVIDER")
+  for spec in 'MANAGED HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN' 'EXPECTED_EUID HARNESS_TEST_MARKER_EXPECTED_EUID' 'OS_ERROR HARNESS_TEST_MARKER_OS_ERROR'; do
+    read -r label marker <<<"$spec"
+    count=$(grep -Fo "$marker" "$PROVIDER" | wc -l)
+    [[ $count == 1 ]] || fail "marker $label count: expected 1 got $count"
   done
-  for kind in safe unsafe disappear; do
-    base="$TMP_TEST/eexist-$kind"; mkdir "$base"; copy="$base/provider.sh"; copy_provider "$copy"; hit="$base/hit"; caught="$base/caught"
-    if [[ $kind == disappear ]]; then action="if name == 'state' and not made: (os.mkdir(name, 0o700, dir_fd=parent_fd), pathlib.Path('$hit').touch()) if phase == 'before_mkdir' else (os.rmdir(name, dir_fd=parent_fd), pathlib.Path('$base/gone').touch()) if phase == 'after_eexist' else None"
-    else action="if phase == 'before_mkdir' and name == 'state' and not made: os.mkdir(name, 0o700, dir_fd=parent_fd); pathlib.Path('$hit').touch()"; [[ $kind == safe ]] || action="$action; os.chmod(name, 0o755, dir_fd=parent_fd)"; fi
-    replace_once "$copy" "$managed" "    $action  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
-    replace_once "$copy" "$catch_line" "            pathlib.Path('$caught').touch()  # provider-copy catch sentinel is injected here"
-    mutate_invoke "$copy" "$base/state"
-    case $kind in safe) expected=0; out="$base/state/project/session"$'\n'; err=''; scope=$'caught\nhit\nprovider.sh\nstate\nstate/project\nstate/project/session';; unsafe) expected=2; out=''; err=$'error: unsafe session state\n'; scope=$'caught\nhit\nprovider.sh\nstate';; disappear) expected=1; out=''; err=$'error: session state operation failed\n'; scope=$'caught\ngone\nhit\nprovider.sh';; esac
-    expect "eexist $kind" "$expected" "$out" "$err"; expect_scope "$base" "$scope"
-    empty_regular "$hit" && empty_regular "$caught" && { [[ $kind != disappear ]] || { empty_regular "$base/gone" && [[ ! -e $base/state ]]; }; } || fail "eexist $kind: injection missed"
-    [[ $kind != unsafe || -d $base/state && ! -L $base/state && $(stat -c %a "$base/state") == 755 && ! -e $base/state/project ]] || fail 'eexist unsafe: winner modified'
+  for phase in before_mkdir after_eexist before_open; do
+    needle="_managed_checkpoint(\"$phase\""
+    [[ $(grep -Fo "$needle" "$PROVIDER" | wc -l) == 1 && $(grep -Fo "$needle" <<<"$managed_body" | wc -l) == 1 ]] || fail "phase $phase global or managed-body count"
   done
-  base="$TMP_TEST/mkdir-replace"; mkdir "$base"; copy="$base/provider.sh"; copy_provider "$copy"; hit="$base/hit"
-  replace_once "$copy" "$managed" "    if phase == 'before_open' and name == 'state' and made: os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.mkdir(name, 0o700, dir_fd=parent_fd); os.chmod(name, 0o755, dir_fd=parent_fd); pathlib.Path('$hit').touch()  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
-  mutate_invoke "$copy" "$base/state"; expect 'mkdir replacement' 2 '' $'error: unsafe session state\n'
-  expect_scope "$base" "$(printf '%s\n' hit provider.sh state state.old)"; empty_regular "$hit" && [[ -d $base/state && ! -L $base/state && $(stat -c %D:%i "$base/state") != "$(stat -c %D:%i "$base/state.old")" && $(stat -c %a "$base/state") == 755 && $(stat -c %a "$base/state.old") == 700 && ! -e $base/state/project ]] || fail 'mkdir replacement modified'
-  base="$TMP_TEST/mkdir-error"; mkdir "$base"; copy="$base/provider.sh"; copy_provider "$copy"; replace_once "$copy" '            os.mkdir(name, 0o700, dir_fd=parent_fd)' "            raise FileNotFoundError(errno.ENOENT, 'gone')"
-  mutate_invoke "$copy" "$base/state"; expect 'mkdir ordinary error' 1 '' $'error: session state operation failed\n'; expect_scope "$base" provider.sh
-  for kind in owner eio; do
-    base="$TMP_TEST/$kind"; mkdir "$base"; copy="$base/provider.sh"; copy_provider "$copy"
-    if [[ $kind == owner ]]; then replace_once "$copy" '    expected_euid = os.geteuid()  # HARNESS_TEST_MARKER_EXPECTED_EUID' "    expected_euid = os.geteuid() + (name == 'state'); pathlib.Path('$base/hit').touch()  # HARNESS_TEST_MARKER_EXPECTED_EUID"; expected=2; err=$'error: unsafe session state\n'; scope=$'hit\nprovider.sh\nstate'
-    else replace_once "$copy" '        pass  # HARNESS_TEST_MARKER_OS_ERROR' '        raise OSError(errno.EIO)  # HARNESS_TEST_MARKER_OS_ERROR'; expected=1; err=$'error: session state operation failed\n'; scope=provider.sh; fi
-    mutate_invoke "$copy" "$base/state"; expect "$kind" "$expected" '' "$err"; expect_scope "$base" "$scope"; [[ $kind != owner ]] || { empty_regular "$base/hit" && [[ ! -e $base/state/project ]]; } || fail 'owner injection missed'
-  done
-  for phase in before_mkdir after_eexist before_open; do [[ $(grep -Fo "_managed_checkpoint(\"$phase\"" "$PROVIDER" | wc -l) == 1 ]] || fail "phase $phase count"; done
   ! grep -q fchmod "$PROVIDER" || fail 'forbidden fchmod'
-  printf 'RESULT PASS  session path safety\n'; exit 0
-fi
+}
+[[ $GROUP == dependency-absent ]] || check_structure
 if [[ $GROUP == roots-static ]]; then
   mkdir "$TMP_TEST/harness" "$TMP_TEST/xdg" "$TMP_TEST/tmp" "$TMP_TEST/physical"
   ln -s "$TMP_TEST/physical" "$TMP_TEST/logical"
-  printf sentinel >"$TMP_TEST/xdg/sentinel"; printf sentinel >"$TMP_TEST/tmp/sentinel"
+  printf sentinel >"$TMP_TEST/xdg/sentinel"
+  printf sentinel >"$TMP_TEST/tmp/sentinel"
   lower_before=$(find "$TMP_TEST/xdg" "$TMP_TEST/tmp" -printf '%p|%y|%m|%s\n' | LC_ALL=C sort)
   invoke harness p s HARNESS_STATE_ROOT="$TMP_TEST/harness/state" XDG_RUNTIME_DIR="$TMP_TEST/xdg" TMPDIR="$TMP_TEST/tmp"
   [[ $RC != 1 ]] || ! cmp -s "$TMP_TEST/err" <(printf 'error: session state operation failed\n') || fail 'root HARNESS: python path engine missing'
   expect 'root HARNESS' 0 "$TMP_TEST/harness/state/p/s"$'\n' ''
   [[ $lower_before == "$(find "$TMP_TEST/xdg" "$TMP_TEST/tmp" -printf '%p|%y|%m|%s\n' | LC_ALL=C sort)" ]] || fail 'root HARNESS: lower priority changed'
-  tmp_before=$(find "$TMP_TEST/tmp" -printf '%P|%y|%m|%s\n' | LC_ALL=C sort); invoke xdg p s -u HARNESS_STATE_ROOT XDG_RUNTIME_DIR="$TMP_TEST/xdg" TMPDIR="$TMP_TEST/tmp"
-  expect 'root XDG' 0 "$TMP_TEST/xdg/aosp-harness-$(id -u)/p/s"$'\n' ''; [[ $tmp_before == "$(find "$TMP_TEST/tmp" -printf '%P|%y|%m|%s\n' | LC_ALL=C sort)" ]] || fail 'root XDG: lower priority changed'
+  tmp_before=$(find "$TMP_TEST/tmp" -printf '%P|%y|%m|%s\n' | LC_ALL=C sort)
+  invoke xdg p s -u HARNESS_STATE_ROOT XDG_RUNTIME_DIR="$TMP_TEST/xdg" TMPDIR="$TMP_TEST/tmp"
+  expect 'root XDG' 0 "$TMP_TEST/xdg/aosp-harness-$(id -u)/p/s"$'\n' ''
+  [[ $tmp_before == "$(find "$TMP_TEST/tmp" -printf '%P|%y|%m|%s\n' | LC_ALL=C sort)" ]] || fail 'root XDG: lower priority changed'
   invoke tmp p s -u HARNESS_STATE_ROOT -u XDG_RUNTIME_DIR TMPDIR="$TMP_TEST/tmp"
   expect 'root TMP' 0 "$TMP_TEST/tmp/aosp-harness-$(id -u)/p/s"$'\n' ''
   default_project="path-default-$$"
+  DEFAULT_ROOT="/tmp/aosp-harness-$(id -u)"
+  DEFAULT_PROJECT_PATH="$DEFAULT_ROOT/$default_project"
+  [[ -e $DEFAULT_ROOT || -L $DEFAULT_ROOT ]] && DEFAULT_ROOT_CREATED=0 || DEFAULT_ROOT_CREATED=1
   invoke default "$default_project" s -u HARNESS_STATE_ROOT -u XDG_RUNTIME_DIR -u TMPDIR
-  expect 'root default' 0 "/tmp/aosp-harness-$(id -u)/$default_project/s"$'\n' ''
-  rmdir "/tmp/aosp-harness-$(id -u)/$default_project/s" "/tmp/aosp-harness-$(id -u)/$default_project"
+  expect 'root default' 0 "$DEFAULT_PROJECT_PATH/s"$'\n' ''
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
-    source=${spec%%|*}; rest=${spec#*|}; label="$source-${rest%%|*}"; value=${rest#*|}
+    source=${spec%%|*}
+    rest=${spec#*|}
+    label="$source-${rest%%|*}"
+    value=${rest#*|}
     case $source in
-      harness) root_env=(HARNESS_STATE_ROOT="$value" XDG_RUNTIME_DIR="$TMP_TEST/xdg" TMPDIR="$TMP_TEST/tmp");;
-      xdg) root_env=(-u HARNESS_STATE_ROOT XDG_RUNTIME_DIR="$value" TMPDIR="$TMP_TEST/tmp");;
-      tmp) root_env=(-u HARNESS_STATE_ROOT -u XDG_RUNTIME_DIR TMPDIR="$value");;
+      harness) root_env=(HARNESS_STATE_ROOT="$value" XDG_RUNTIME_DIR="$TMP_TEST/xdg" TMPDIR="$TMP_TEST/tmp") ;;
+      xdg) root_env=(-u HARNESS_STATE_ROOT XDG_RUNTIME_DIR="$value" TMPDIR="$TMP_TEST/tmp") ;;
+      tmp) root_env=(-u HARNESS_STATE_ROOT -u XDG_RUNTIME_DIR TMPDIR="$value") ;;
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
-  while IFS= read -r relative; do path="$TMP_TEST/isolation/$relative"; [[ -d $path && ! -L $path && $(stat -c %u:%a "$path") == "$(id -u):700" ]] || fail "isolation unsafe: $relative"; done <<<"$expected"
+  while IFS= read -r relative; do
+    path="$TMP_TEST/isolation/$relative"
+    [[ -d $path && ! -L $path && $(stat -c %u:%a "$path") == "$(id -u):700" ]] || fail "isolation unsafe: $relative"
+  done <<<"$expected"
   for kind in link file mode; do for layer in root project session; do
-    base="$TMP_TEST/static-$kind-$layer"; mkdir "$base"; root="$base/state"; target=$root
-    [[ $layer == root ]] || { mkdir -m 700 "$root"; target="$root/project"; }
-    [[ $layer != session ]] || { mkdir -m 700 "$target"; target="$target/session"; }
+    base="$TMP_TEST/static-$kind-$layer"
+    mkdir "$base"
+    root="$base/state"
+    target=$root
+    [[ $layer == root ]] || {
+      mkdir -m 700 "$root"
+      target="$root/project"
+    }
+    [[ $layer != session ]] || {
+      mkdir -m 700 "$target"
+      target="$target/session"
+    }
     case $kind in
-      link) mkdir "$base/victim"; printf sentinel >"$base/victim/sentinel"; ln -s "$base/victim" "$target"
-        victim_before=$(stat -c '%D|%i|%a' "$base/victim"); victim_hash=$(sha256sum "$base/victim/sentinel");;
-      file) printf sentinel >"$target";;
-      mode) mkdir -m 755 "$target";;
+      link)
+        mkdir "$base/victim"
+        printf sentinel >"$base/victim/sentinel"
+        ln -s "$base/victim" "$target"
+        victim_before=$(stat -c '%D|%i|%a' "$base/victim")
+        victim_hash=$(sha256sum "$base/victim/sentinel")
+        ;;
+      file) printf sentinel >"$target" ;;
+      mode) mkdir -m 755 "$target" ;;
     esac
     before=$(find "$base" -printf '%P|%y|%l|%D|%i|%m|%s\n' | LC_ALL=C sort)
-    invoke static project session HARNESS_STATE_ROOT="$root"; expect "static $kind/$layer" 2 '' $'error: unsafe session state\n'
+    invoke static project session HARNESS_STATE_ROOT="$root"
+    expect "static $kind/$layer" 2 '' $'error: unsafe session state\n'
     [[ $before == "$(find "$base" -printf '%P|%y|%l|%D|%i|%m|%s\n' | LC_ALL=C sort)" ]] || fail "static $kind/$layer: inventory changed"
     [[ $kind != link || $victim_before == "$(stat -c '%D|%i|%a' "$base/victim")" && $victim_hash == "$(sha256sum "$base/victim/sentinel")" ]] || fail "static link/$layer: victim changed"
   done; done
-  printf 'RESULT PASS  session path safety\n'
+  pass
   exit 0
 fi
-if [[ ${HARNESS_TEST_SELF_CHECK:-0} == 0 ]]; then
+if [[ $GROUP == source-validate && ${HARNESS_TEST_SELF_CHECK:-0} == 0 ]]; then
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
-source "$FOUNDATION"
-[[ $MISSING == none ]] || unset -f "$MISSING"
+if [[ $MISSING == all ]]; then
+  unset -f _harness_component_is_safe harness_validate_feature_name _harness_session_state_foundation_path _harness_session_state_run 2>/dev/null || :
+else
+  source "$FOUNDATION"
+  [[ $MISSING == none ]] || unset -f "$MISSING"
+fi
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
@@ -208,49 +220,59 @@ cp "$AUDIT/names-before" "$AUDIT/names-expected"
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
+if [[ $GROUP == dependency-absent ]]; then
+  source_case all absent all-missing || exit $?
+  pass
+  exit 0
+fi
 for spec in 'none present present' 'harness_validate_feature_name absent missing-validate' '_harness_session_state_foundation_path absent missing-path' '_harness_session_state_run absent missing-run'; do
-  read -r missing expected label <<<"$spec"; source_case "$missing" "$expected" "$label" || exit $?
+  read -r missing expected label <<<"$spec"
+  source_case "$missing" "$expected" "$label" || exit $?
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
-  [[ $# == 1 && $1 != session-ok ]] || { printf 'validation detail must be discarded\n' >&2; return 77; }
+  [[ $# == 1 && $1 != session-ok ]] || {
+    printf 'validation detail must be discarded\n' >&2
+    return 77
+  }
 }
 # shellcheck source=/dev/null
 source "$PROVIDER"
 capture_core() {
-  : >"$TMP_TEST/out"; : >"$TMP_TEST/err"
+  : >"$TMP_TEST/out"
+  : >"$TMP_TEST/err"
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
-printf 'RESULT PASS  session path safety\n'
+pass
```
