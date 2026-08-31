# review 包 61e5fa8f..fb161f9f

## commit 列表

```
fb161f9 fix: pin Claude verifier adb target
```

## diff --stat

```
 claude-code/features/.harness/tests/test-harness.sh |  5 ++++-
 claude-code/features/dev-sidebar/verify-sidebar.sh  | 17 +++++++++++++++--
 2 files changed, 19 insertions(+), 3 deletions(-)
```

## diff

```diff
diff --git a/claude-code/features/.harness/tests/test-harness.sh b/claude-code/features/.harness/tests/test-harness.sh
index 8d06ce5..b21a4e6 100755
--- a/claude-code/features/.harness/tests/test-harness.sh
+++ b/claude-code/features/.harness/tests/test-harness.sh
@@ -130,31 +130,34 @@ set +e
 crash_error_output="$(DEMO_CRASH_QUERY_FAIL=1 \
   "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo --since 200 2>&1)"
 crash_error_rc=$?
 set -e
 test "$crash_error_rc" -ne 0
 grep -Fq 'FAIL  crash buffer 查询失败' <<<"$crash_error_output"
 grep -Fq 'RESULT FAIL' <<<"$crash_error_output"
 
 # logcat 的纯整数 -T 参数会与“最近 N 行”语义冲突；epoch 秒必须规范化为带小数点。
 adb() {
+  [ "$1" = -s ] || return 1
+  [ "$2" = demo-serial ] || return 1
+  shift 2
   case "$*" in
     "shell getprop sys.boot_completed") echo 1 ;;
     "shell pidof system_server") echo 1423 ;;
     "logcat -b crash -d -v epoch -T 200.000") return 0 ;;
     "shell service list") echo "52 sidebar: [android.sidebar.ISidebar]" ;;
     "shell pm list packages") echo "package:com.android.sidebar" ;;
     *) return 1 ;;
   esac
 }
 export -f adb
-normalized_since_output="$("$ROOT/features/dev-sidebar/verify-sidebar.sh" --since 200)"
+normalized_since_output="$(ANDROID_SERIAL=demo-serial "$ROOT/features/dev-sidebar/verify-sidebar.sh" --since 200)"
 unset -f adb
 grep -Fq 'PASS  crash buffer 自 200 起无崩溃' <<<"$normalized_since_output"
 
 BRANCH_FIXTURE="$(mktemp -d)"
 mkdir -p "$BRANCH_FIXTURE/features/dev-test" "$BRANCH_FIXTURE/repos/one"
 printf '%s\n' \
   'repos/one - - first repo' \
   'repos/two - - second repo' \
   > "$BRANCH_FIXTURE/features/dev-test/repos.tsv"
 git -C "$BRANCH_FIXTURE/repos/one" init -q -b dev-test
diff --git a/claude-code/features/dev-sidebar/verify-sidebar.sh b/claude-code/features/dev-sidebar/verify-sidebar.sh
index fcd10cf..b34ff2a 100755
--- a/claude-code/features/dev-sidebar/verify-sidebar.sh
+++ b/claude-code/features/dev-sidebar/verify-sidebar.sh
@@ -24,39 +24,52 @@ while [ "$#" -gt 0 ]; do
         echo "usage: $0 [--demo] [--allow-skip] [--since <epoch-seconds>]" >&2
         exit 2
       }
       CRASH_SINCE="$1"
       ;;
     *) echo "usage: $0 [--demo] [--allow-skip] [--since <epoch-seconds>]" >&2; exit 2 ;;
   esac
   shift
 done
 
+if [[ "$DEMO" -eq 0 && "$ALLOW_SKIP" -eq 1 ]]; then
+  echo 'error: --allow-skip requires --demo' >&2
+  exit 2
+fi
+if [[ "$DEMO" -eq 0 ]]; then
+  serial="${ANDROID_SERIAL-}"
+  if [[ -z "$serial" || ! "$serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
+    echo 'error: set ANDROID_SERIAL to a safe, explicit target serial' >&2
+    exit 2
+  fi
+  ADB=(adb -s "$serial")
+fi
+
 pass=0; fail=0; skip=0
 ok()   { echo "PASS  $1"; pass=$((pass+1)); }
 no()   { echo "FAIL  $1"; fail=$((fail+1)); }
 sk()   { echo "SKIP  $1"; skip=$((skip+1)); }
 
 # adb 包装：demo 下返回预置样本，真实下调真 adb
 adb_shell() {
   if [ $DEMO -eq 1 ]; then
     case "$*" in
       "getprop sys.boot_completed")      echo "1" ;;
       "pidof system_server")             echo "1423" ;;
       "service list")                    echo "52  sidebar: [android.sidebar.ISidebar]" ;;
       "pm list packages")
         [ "${DEMO_APP_INSTALLED:-1}" == "1" ] && echo "package:com.android.sidebar"
         ;;
       *)                                  echo "" ;;
     esac
   else
-    adb shell "$@" 2>/dev/null
+    "${ADB[@]}" shell "$@" 2>/dev/null
   fi
 }
 
 is_epoch() {
   [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
 }
 
 detect_boot_epoch() {
   if [ "$DEMO" -eq 1 ]; then
     echo "${DEMO_BOOT_TIME:-0}"
@@ -68,21 +81,21 @@ detect_boot_epoch() {
 read_crash_since() {
   local since="$1"
   if [ "$DEMO" -eq 1 ]; then
     [ "${DEMO_CRASH_QUERY_FAIL:-0}" != "1" ] || return 1
     printf '%s\n' "${DEMO_CRASH_LOG:-}" | awk -v since="$since" '
       $1 ~ /^[0-9]+([.][0-9]+)?$/ && ($1 + 0) >= (since + 0) { print }
     '
   else
     local logcat_since="$since"
     [[ "$logcat_since" == *.* ]] || logcat_since="${logcat_since}.000"
-    adb logcat -b crash -d -v epoch -T "$logcat_since" 2>/dev/null
+    "${ADB[@]}" logcat -b crash -d -v epoch -T "$logcat_since" 2>/dev/null
   fi
 }
 
 if [ -z "$CRASH_SINCE" ]; then
   CRASH_SINCE="$(detect_boot_epoch 2>/dev/null || true)"
 fi
 
 echo "===== verify dev-sidebar (demo=$DEMO crash_since=${CRASH_SINCE:-unknown}) ====="
 
 # 1) 设备真的起来了
```
