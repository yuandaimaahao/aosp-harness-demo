# review 包 8a164f21..c7a18edf

## commit 列表

```
c7a18ed test(session): add snapshot assurance matrix
```

## diff --stat

```
 tests/test-session-snapshot-assurance.sh | 346 +++++++++++++++++++++++++++++++
 1 file changed, 346 insertions(+)
```

## diff

```diff
diff --git a/tests/test-session-snapshot-assurance.sh b/tests/test-session-snapshot-assurance.sh
new file mode 100644
index 0000000..0bd3208
--- /dev/null
+++ b/tests/test-session-snapshot-assurance.sh
@@ -0,0 +1,346 @@
+#!/usr/bin/env bash
+set -u
+here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
+repo=$(git -C "$here" rev-parse --show-toplevel)
+# 03b1 session snapshot assurance: provider-copy 动态矩阵。
+# 结构: CLI 分流 -> inert/fail-closed -> 注入副本 -> 动态矩阵 -> 固定摘要。
+# 成功唯一摘要: RESULT PASS  session snapshot assurance
+# 注意: 注释只写摘要文字，不得包含固定摘要的 printf 调用（步骤 4/5 探针按该调用字面量的出现次数定位）。
+case ${1-} in
+  '' | all) ;;
+  --dependency-absent) mode=absent ;;
+  *) exit 1 ;;
+esac
+[[ $# -le 1 ]] || exit 1
+provider=$repo/common/.harness/lib/session-state-snapshot.sh
+if [[ ! -e $provider && ! -L $provider ]]; then
+  printf 'RESULT PASS  session snapshot assurance\n'
+  exit 0
+fi
+[[ -f $provider && ! -L $provider ]] || exit 1
+bash -n "$provider" 2>/dev/null || exit 1
+bash -c 'source "$1"' _ "$provider" >/dev/null 2>&1 || exit 1
+for fn in _harness_session_snapshot_worker _harness_session_snapshot_write_core _harness_session_snapshot_read_core; do
+  bash -c 'source "$1/common/.harness/lib/session-state-foundation.sh" && source "$1/common/.harness/lib/session-state-path.sh" && source "$2" && declare -F "$3" >/dev/null' _ "$repo" "$provider" "$fn" >/dev/null 2>&1 || exit 1
+done
+for marker in CAPTURE_READY SNAPSHOT_MANAGED_BEFORE_OPEN MANAGED_EXPECTED_EUID \
+  SNAPSHOT_EXPECTED_EUID SNAPSHOT_BEFORE_OPEN TEMP_BEFORE_PUBLISH PUBLISH_RESULT OS_ERROR; do
+  [[ $(rg -c "HARNESS_TEST_MARKER_$marker" "$provider") == 1 ]] || exit 1
+done
+[[ $(rg -c 'renameat2' "$provider") == 1 ]] || exit 1
+if rg -q 'os\.(replace|link|rename)\(' "$provider"; then exit 1; fi
+if [[ ${mode-} == absent ]]; then
+  printf 'RESULT PASS  session snapshot assurance\n'
+  exit 0
+fi
+tmp=$(mktemp -d)
+trap 'rm -rf -- "$tmp"' EXIT
+export TMPDIR=$tmp
+copy=$tmp/provider.sh
+python3 - "$provider" "$copy" <<'PY' || exit 1
+import sys
+text = open(sys.argv[1]).read()
+replacements = {
+    "    return os.geteuid()  # HARNESS_TEST_MARKER_MANAGED_EXPECTED_EUID": """    return os.geteuid() + (1 if os.environ.get("ASSURANCE_OWNER") == "managed" else 0)  # HARNESS_TEST_MARKER_MANAGED_EXPECTED_EUID""",
+    "    return os.geteuid()  # HARNESS_TEST_MARKER_SNAPSHOT_EXPECTED_EUID": """    return os.geteuid() + (1 if os.environ.get("ASSURANCE_OWNER") == "snapshot" else 0)  # HARNESS_TEST_MARKER_SNAPSHOT_EXPECTED_EUID""",
+    "    pass  # HARNESS_TEST_MARKER_SNAPSHOT_MANAGED_BEFORE_OPEN": """    action = os.environ.get("ASSURANCE_MANAGED")
+    if action and name == os.environ.get("ASSURANCE_LAYER"):
+        os.rename(name, name + ".old", src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
+        if action == "link": os.symlink(os.environ["ASSURANCE_VICTIM"], name, dir_fd=parent_fd)
+        if action == "inode": os.mkdir(name, 0o700, dir_fd=parent_fd)
+        try: info = os.stat(name, dir_fd=parent_fd, follow_symlinks=False); value = f"{info.st_dev}:{info.st_ino}"
+        except FileNotFoundError: value = "absent"
+        open(os.environ["ASSURANCE_REPLACEMENT"], "w").write(value)
+    pass  # HARNESS_TEST_MARKER_SNAPSHOT_MANAGED_BEFORE_OPEN""",
+    "    pass  # HARNESS_TEST_MARKER_SNAPSHOT_BEFORE_OPEN": """    action = os.environ.get("ASSURANCE_SNAPSHOT")
+    if action:
+        os.rename("feature", "feature.old", src_dir_fd=dir_fd, dst_dir_fd=dir_fd)
+        if action == "link": os.symlink(os.environ["ASSURANCE_VICTIM"], "feature", dir_fd=dir_fd)
+        if action == "inode":
+            fd = os.open("feature", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600, dir_fd=dir_fd); os.write(fd, b"alpha\\n"); os.close(fd)
+        try: info = os.stat("feature", dir_fd=dir_fd, follow_symlinks=False); value = f"{info.st_dev}:{info.st_ino}"
+        except FileNotFoundError: value = "absent"
+        open(os.environ["ASSURANCE_REPLACEMENT"], "w").write(value)
+    pass  # HARNESS_TEST_MARKER_SNAPSHOT_BEFORE_OPEN""",
+    "        os.unlink(temp, dir_fd=dir_fd); temp = None\n        try:\n            current = read_snapshot(dir_fd)": """        os.unlink(temp, dir_fd=dir_fd); temp = None
+        if os.environ.get("ASSURANCE_EXPECT_NO_TEMP") and any(name.startswith(".snapshot-") for name in os.listdir(dir_fd)): raise OSError(errno.EIO, "temp survived EEXIST")
+        try:
+            current = read_snapshot(dir_fd)""",
+    "    pass  # HARNESS_TEST_MARKER_TEMP_BEFORE_PUBLISH": """    barrier = os.environ.get("ASSURANCE_BARRIER")
+    if barrier:
+        open(barrier, "w").close()
+        while os.path.exists(barrier): __import__("time").sleep(.01)
+    pass  # HARNESS_TEST_MARKER_TEMP_BEFORE_PUBLISH""",
+    "    pass  # HARNESS_TEST_MARKER_PUBLISH_RESULT": """    action = os.environ.get("ASSURANCE_PUBLISH")
+    if action == "symbol": raise AttributeError
+    if action == "enosys": return errno.ENOSYS
+    if action == "signal-success":
+        call = getattr(ctypes.CDLL(None, use_errno=True), "renameat2")
+        if call(dir_fd, temp.encode(), dir_fd, b"feature", 1) == 0: os.kill(os.getpid(), signal.SIGTERM)
+    if action and action.startswith("eexist"):
+        if action in ("eexist-same", "eexist-different"):
+            payload = "alpha\\n" if action.endswith("same") else "beta\\n"
+            fd = os.open("feature", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600, dir_fd=dir_fd); os.write(fd, payload.encode()); os.close(fd)
+            info = os.stat("feature", dir_fd=dir_fd); digest = __import__("hashlib").sha256(payload.encode()).hexdigest()
+            open(os.environ["ASSURANCE_WINNER_STATE"], "w").write(f"{info.st_dev}:{info.st_ino}:{info.st_uid}:{info.st_mode & 0o777:o}:{info.st_nlink}:{info.st_size}\\n{digest}\\n")
+        if action == "eexist-unsafe": os.symlink(os.environ["ASSURANCE_VICTIM"], "feature", dir_fd=dir_fd)
+        try: info = os.stat("feature", dir_fd=dir_fd, follow_symlinks=False); value = f"{info.st_dev}:{info.st_ino}"
+        except FileNotFoundError: value = "absent"
+        open(os.environ["ASSURANCE_PUBLISH_IDENTITY"], "w").write(value)
+        return errno.EEXIST
+    pass  # HARNESS_TEST_MARKER_PUBLISH_RESULT""",
+    "    pass  # HARNESS_TEST_MARKER_OS_ERROR": """    if os.environ.get("ASSURANCE_EIO"): raise OSError(errno.EIO, "injected")
+    pass  # HARNESS_TEST_MARKER_OS_ERROR""",
+    "        chunk = os.read(fd, 130 - total)": "        chunk = os.read(fd, min(1, 130 - total))",
+    "        while data: data = data[os.write(temp_fd, data):]": """        while data: data = data[os.write(temp_fd, data):]
+        if os.environ.get("ASSURANCE_CLEANUP_CLOSE"):
+            real_close, owned, managed_failed = os.close, temp_fd, [False]
+            def close_fault(fd):
+                with open(os.environ["ASSURANCE_CLEANUP_LOG"], "a") as log: log.write(f"{fd}\\n")
+                if fd == owned or not managed_failed[0]:
+                    if fd != owned: managed_failed[0] = True
+                    raise OSError(errno.EIO, "cleanup close")
+                return real_close(fd)
+            os.close = close_fault
+            os.kill(os.getpid(), signal.SIGTERM)""",
+    "        os.close(owned_fd)": """        os.close(owned_fd)
+        if os.environ.get("ASSURANCE_CLOSE_SIGNAL"): os.kill(os.getpid(), signal.SIGTERM)""",
+    "    first_signal[0] = number": """    first_signal[0] = number
+    if os.environ.get("ASSURANCE_LATCH_SECOND"): os.kill(os.getpid(), signal.SIGHUP)""",
+    "    raise Interrupted": """    caught = os.environ.get("ASSURANCE_CAUGHT")
+    if caught: open(caught, "w").close(); __import__("time").sleep(.2)
+    raise Interrupted""",
+    "                try: os.unlink(temp, dir_fd=dir_fd)\n                except OSError as exc:": """                try:
+                    os.unlink(temp, dir_fd=dir_fd)
+                    if os.environ.get("ASSURANCE_UNLINK_LOG"): open(os.environ["ASSURANCE_UNLINK_LOG"], "a").write("success\\n")
+                except OSError as exc:
+                    if os.environ.get("ASSURANCE_UNLINK_LOG"): open(os.environ["ASSURANCE_UNLINK_LOG"], "a").write(errno.errorcode.get(exc.errno, "EUNKNOWN") + "\\n")""",
+    "    : # HARNESS_TEST_MARKER_CAPTURE_READY": """    if [[ -n ${ASSURANCE_CAPTURE-} ]]; then printf '%s\\n' "$ASSURANCE_CAPTURE" >"$path_file"; fi
+    : # HARNESS_TEST_MARKER_CAPTURE_READY""",
+}
+for old, new in replacements.items():
+    assert text.count(old) == 1, old
+    text = text.replace(old, new)
+open(sys.argv[2], "w").write(text)
+PY
+export HARNESS_STATE_ROOT=$tmp/state
+source "$repo/common/.harness/lib/session-state-foundation.sh"
+source "$repo/common/.harness/lib/session-state-path.sh"
+# shellcheck source=/dev/null
+source "$copy"
+failures=0
+checks=0
+check_eq() {
+  local label=$1 want=$2 got=$3
+  checks=$((checks + 1))
+  if [[ $got != "$want" ]]; then
+    printf 'FAIL %s want=%q got=%q\n' "$label" "$want" "$got" >&2
+    failures=$((failures + 1))
+  fi
+}
+run_rc() {
+  local want=$1
+  shift
+  local rc out=$tmp/out err=$tmp/err command=$1
+  "$@" >"$out" 2>"$err"
+  rc=$?
+  checks=$((checks + 1))
+  if [[ $rc != "$want" || -s $err || ($want != 0 && -s $out) || ($command == *_write_core && -s $out) ]]; then
+    printf 'FAIL rc want=%s got=%s command=%q managed=%s layer=%s snapshot=%s stderr=%q\n' \
+      "$want" "$rc" "$*" "${ASSURANCE_MANAGED-}" "${ASSURANCE_LAYER-}" \
+      "${ASSURANCE_SNAPSHOT-}" "$(<"$err")" >&2
+    failures=$((failures + 1))
+  fi
+}
+reset() { rm -rf -- "$HARNESS_STATE_ROOT" "$HARNESS_STATE_ROOT.old"; }
+leaf() { printf '%s/project/session/feature' "$HARNESS_STATE_ROOT"; }
+file_state() {
+  stat -Lc '%d:%i:%u:%a:%h:%s' "$1"
+  sha256sum "$1" | cut -d ' ' -f 1
+}
+identity() { [[ -e $1 || -L $1 ]] && stat -c '%d:%i' "$1" || printf absent; }
+shape() { if [[ -L $1 ]]; then printf 'link:%s' "$(readlink "$1")"; elif [[ -d $1 ]]; then printf 'dir:%s:%s' "$(stat -c '%u:%a' "$1")" "$(find "$1" -mindepth 1 -maxdepth 1 | wc -l | xargs)"; elif [[ -f $1 ]]; then
+  printf 'file:%s:' "$(stat -c '%u:%a:%h:%s' "$1")"
+  sha256sum "$1" | cut -d ' ' -f 1
+else printf absent; fi; }
+moved_leaf() {
+  case $1 in
+    state) printf '%s.old/project/session/feature' "$HARNESS_STATE_ROOT" ;;
+    project) printf '%s/project.old/session/feature' "$HARNESS_STATE_ROOT" ;;
+    session) printf '%s/project/session.old/feature' "$HARNESS_STATE_ROOT" ;;
+  esac
+}
+layer_path() { case $1 in state) printf %s "$HARNESS_STATE_ROOT" ;; project) printf %s "$HARNESS_STATE_ROOT/project" ;; session) printf %s "$HARNESS_STATE_ROOT/project/session" ;; esac }
+temp_count() { find "$tmp" -name '.snapshot-*' | wc -l | xargs; }
+prepare() {
+  reset
+  _harness_session_snapshot_write_core project session alpha
+}
+victim=$tmp/victim
+printf 'victim\n' >"$victim"
+chmod 0600 "$victim"
+mkdir -m 0700 "$tmp/victim-dir"
+for marker in CAPTURE_READY SNAPSHOT_MANAGED_BEFORE_OPEN MANAGED_EXPECTED_EUID \
+  SNAPSHOT_EXPECTED_EUID SNAPSHOT_BEFORE_OPEN TEMP_BEFORE_PUBLISH PUBLISH_RESULT OS_ERROR; do
+  check_eq "marker $marker" 1 "$(rg -c "HARNESS_TEST_MARKER_$marker" "$copy")"
+done
+check_eq 'renameat2 call count' 1 "$(rg -c 'renameat2' "$provider")"
+fallback=absent
+rg -q 'os\.(replace|link|rename)\(' "$provider" && fallback=present
+check_eq 'forbidden publish fallback' absent "$fallback"
+other=$tmp/other/root/project/session
+mkdir -p "$other"
+chmod 0700 "$tmp/other/root" "$tmp/other/root/project" "$other"
+ASSURANCE_CAPTURE=$other run_rc 0 _harness_session_snapshot_write_core project session alpha
+check_eq 'capture canonical winner' alpha "$(<"$(leaf)")"
+check_eq 'capture recreated destination' absent "$([[ -e $other/feature ]] && echo present || echo absent)"
+capture_name=$(find "$tmp" -maxdepth 1 -name 'snapshot-path.*' -print -quit)
+check_eq 'capture same-name recreation' "$other" "$(<"$capture_name")"
+check_eq 'capture temp' 0 "$(temp_count)"
+rm -f -- "$capture_name"
+for op in read write; do
+  for owner in managed snapshot; do
+    prepare
+    before=$(file_state "$(leaf)")
+    args=("_harness_session_snapshot_${op}_core" project session)
+    [[ $op == write ]] && args+=(beta)
+    ASSURANCE_OWNER=$owner run_rc 2 "${args[@]}"
+    check_eq "$op $owner owner winner" "$before" "$(file_state "$(leaf)")"
+    check_eq "$op $owner owner temp" 0 "$(temp_count)"
+  done
+done
+victim_dir_before=$(stat -Lc '%d:%i:%u:%a:%h' "$tmp/victim-dir")
+replacement=$tmp/replacement
+for op in read write; do
+  for layer in state project session; do
+    for action in link inode missing; do
+      prepare
+      before=$(file_state "$(leaf)")
+      expected=2
+      [[ $action == missing ]] && expected=1
+      rm -f -- "$replacement"
+      args=("_harness_session_snapshot_${op}_core" project session)
+      [[ $op == write ]] && args+=(beta)
+      ASSURANCE_MANAGED=$action ASSURANCE_LAYER=$layer ASSURANCE_VICTIM=$tmp/victim-dir ASSURANCE_REPLACEMENT=$replacement \
+        run_rc "$expected" "${args[@]}"
+      check_eq "$op managed $layer/$action winner" "$before" \
+        "$(file_state "$(moved_leaf "$layer")")"
+      check_eq "$op managed $layer/$action victim" "$victim_dir_before" \
+        "$(stat -Lc '%d:%i:%u:%a:%h' "$tmp/victim-dir")"
+      case $action in link) expected_shape="link:$tmp/victim-dir" ;; inode) expected_shape="dir:$(id -u):700:0" ;; missing) expected_shape=absent ;; esac
+      check_eq "$op managed $layer/$action replacement identity" "$(<"$replacement")" "$(identity "$(layer_path "$layer")")"
+      check_eq "$op managed $layer/$action replacement shape" "$expected_shape" "$(shape "$(layer_path "$layer")")"
+      check_eq "$op managed $layer/$action temp" 0 "$(temp_count)"
+    done
+  done
+done
+victim_before=$(file_state "$victim")
+for op in read write; do
+  for action in link inode missing; do
+    prepare
+    before=$(file_state "$(leaf)")
+    expected=2
+    [[ $action == missing ]] && expected=1
+    rm -f -- "$replacement"
+    args=("_harness_session_snapshot_${op}_core" project session)
+    [[ $op == write ]] && args+=(beta)
+    ASSURANCE_SNAPSHOT=$action ASSURANCE_VICTIM=$victim ASSURANCE_REPLACEMENT=$replacement \
+      run_rc "$expected" "${args[@]}"
+    check_eq "$op snapshot $action winner" "$before" "$(file_state "$(leaf).old")"
+    check_eq "$op snapshot $action victim" "$victim_before" "$(file_state "$victim")"
+    case $action in link) expected_shape="link:$victim" ;; inode) expected_shape="file:$(id -u):600:1:6:$(printf 'alpha\n' | sha256sum | cut -d ' ' -f 1)" ;; missing) expected_shape=absent ;; esac
+    check_eq "$op snapshot $action replacement identity" "$(<"$replacement")" "$(identity "$(leaf)")"
+    check_eq "$op snapshot $action replacement shape" "$expected_shape" "$(shape "$(leaf)")"
+    check_eq "$op snapshot $action temp" 0 "$(temp_count)"
+  done
+done
+prepare
+before=$(file_state "$(leaf)")
+run_rc 0 _harness_session_snapshot_read_core project session
+check_eq 'one-byte short read' 616c7068610a "$(od -An -tx1 "$tmp/out" | tr -d ' \n')"
+check_eq 'one-byte short read winner' "$before" "$(file_state "$(leaf)")"
+check_eq 'one-byte short read victim' "$victim_before" "$(file_state "$victim")"
+check_eq 'one-byte short read temp' 0 "$(temp_count)"
+prepare
+before=$(file_state "$(leaf)")
+ASSURANCE_EIO=1 run_rc 1 _harness_session_snapshot_read_core project session
+check_eq 'read EIO winner' "$before" "$(file_state "$(leaf)")"
+check_eq 'read EIO victim' "$victim_before" "$(file_state "$victim")"
+check_eq 'read EIO temp' 0 "$(temp_count)"
+reset
+ASSURANCE_EIO=1 run_rc 1 _harness_session_snapshot_write_core project session alpha
+check_eq 'write EIO winner' absent "$([[ -e $(leaf) ]] && echo present || echo absent)"
+check_eq 'write EIO victim' "$victim_before" "$(file_state "$victim")"
+check_eq 'write EIO temp' 0 "$(temp_count)"
+publish_identity=$tmp/publish-identity winner_state=$tmp/winner-state
+for action in symbol enosys eexist-same eexist-different eexist-unsafe eexist-missing; do
+  reset
+  rm -f -- "$publish_identity" "$winner_state"
+  expected=1
+  [[ $action == eexist-same ]] && expected=0
+  [[ $action == eexist-different ]] && expected=3
+  [[ $action == eexist-unsafe ]] && expected=2
+  ASSURANCE_PUBLISH=$action ASSURANCE_VICTIM=$victim ASSURANCE_EXPECT_NO_TEMP=1 ASSURANCE_PUBLISH_IDENTITY=$publish_identity ASSURANCE_WINNER_STATE=$winner_state \
+    run_rc "$expected" _harness_session_snapshot_write_core project session alpha
+  case $action in
+    eexist-same | eexist-different)
+      check_eq "$action winner" "$(<"$winner_state")" "$(file_state "$(leaf)")"
+      check_eq "$action identity" "$(<"$publish_identity")" "$(identity "$(leaf)")"
+      ;;
+    eexist-unsafe)
+      check_eq "$action identity" "$(<"$publish_identity")" "$(identity "$(leaf)")"
+      check_eq "$action shape" "link:$victim" "$(shape "$(leaf)")"
+      ;;
+    eexist-missing)
+      check_eq "$action identity" "$(<"$publish_identity")" "$(identity "$(leaf)")"
+      check_eq "$action shape" absent "$(shape "$(leaf)")"
+      ;;
+    *) check_eq "$action leaf" absent "$([[ -e $(leaf) ]] && echo present || echo absent)" ;;
+  esac
+  check_eq "$action victim" "$victim_before" "$(file_state "$victim")"
+  check_eq "$action temp" 0 "$(temp_count)"
+done
+cleanup_log=$tmp/cleanup-log
+unlink_log=$tmp/unlink-log
+for action in close close-latch cleanup-close publish-success; do
+  reset
+  : >"$cleanup_log"
+  : >"$unlink_log"
+  case $action in
+    close) ASSURANCE_CLOSE_SIGNAL=1 run_rc 143 _harness_session_snapshot_write_core project session alpha ;;
+    close-latch) ASSURANCE_CLOSE_SIGNAL=1 ASSURANCE_LATCH_SECOND=1 run_rc 143 _harness_session_snapshot_write_core project session alpha ;;
+    cleanup-close) ASSURANCE_CLEANUP_CLOSE=1 ASSURANCE_CLEANUP_LOG=$cleanup_log run_rc 143 _harness_session_snapshot_write_core project session alpha ;;
+    publish-success) ASSURANCE_PUBLISH=signal-success ASSURANCE_UNLINK_LOG=$unlink_log run_rc 143 _harness_session_snapshot_write_core project session alpha ;;
+  esac
+  expected_shape=absent
+  [[ $action == publish-success ]] && expected_shape='file:'"$(id -u)"':600:1:6:'"$(printf 'alpha\n' | sha256sum | cut -d ' ' -f 1)"
+  check_eq "$action signal winner" "$expected_shape" "$(shape "$(leaf)")"
+  check_eq "$action signal temp" 0 "$(temp_count)"
+  [[ $action != cleanup-close ]] || check_eq "$action all close attempts" 5 "$(wc -l <"$cleanup_log" | xargs)"
+  [[ $action != publish-success ]] || check_eq "$action unlink errno" ENOENT "$(<"$unlink_log")"
+done
+for item in HUP:129:TERM INT:130:TERM TERM:143:HUP; do
+  IFS=: read -r first expected second <<<"$item"
+  reset
+  barrier=$tmp/barrier caught=$tmp/caught
+  rm -f -- "$barrier" "$caught"
+  ASSURANCE_BARRIER=$barrier ASSURANCE_CAUGHT=$caught \
+    _harness_session_snapshot_worker write project session alpha &
+  worker=$!
+  while [[ ! -e $barrier ]]; do sleep .01; done
+  check_eq "$first worker pid" python3 "$(ps -o comm= -p "$worker" | xargs)"
+  check_eq "$first pending temp" 1 "$(temp_count)"
+  kill -s "$first" "$worker"
+  while [[ ! -e $caught ]]; do sleep .01; done
+  kill -s "$second" "$worker" 2>/dev/null || true
+  wait "$worker"
+  rc=$?
+  check_eq "$first first-signal rc" "$expected" "$rc"
+  check_eq "$first winner" absent "$([[ -e $(leaf) ]] && echo present || echo absent)"
+  check_eq "$first cleanup" 0 "$(temp_count)"
+done
+if ((failures)); then
+  printf 'RESULT FAIL snapshot assurance checks=%d failures=%d\n' "$checks" "$failures"
+  exit 1
+fi
+printf 'RESULT PASS  session snapshot assurance\n'
```
