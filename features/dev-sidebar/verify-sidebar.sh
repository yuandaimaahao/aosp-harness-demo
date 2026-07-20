#!/bin/bash
# ③ 验证闭环层：dev-sidebar 的确定性验证脚本 —— 就是这个 feature 的"测试"
#
#   输出只有确定性的 PASS / FAIL / SKIP（中间态会诱导 agent 把模糊输出读成成功）。
#   四步断言：设备起来了 → system_server 存活 → 无新增 crash → 新服务/新 app 存在。
#
# 用法：
#   ./verify-sidebar.sh          # 真实模式：走 adb 断言（需连着目标设备）
#   ./verify-sidebar.sh --since 1753000000.000  # 只检查该 epoch 时间之后的 crash
#   ./verify-sidebar.sh --demo                # DEMO 模式
#   ./verify-sidebar.sh --demo --allow-skip   # 探索期显式允许 SKIP
set -uo pipefail

DEMO=0
ALLOW_SKIP=0
CRASH_SINCE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --demo) DEMO=1 ;;
    --allow-skip) ALLOW_SKIP=1 ;;
    --since)
      shift
      [ "$#" -gt 0 ] || {
        echo "usage: $0 [--demo] [--allow-skip] [--since <epoch-seconds>]" >&2
        exit 2
      }
      CRASH_SINCE="$1"
      ;;
    *) echo "usage: $0 [--demo] [--allow-skip] [--since <epoch-seconds>]" >&2; exit 2 ;;
  esac
  shift
done

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
    adb shell "$@" 2>/dev/null
  fi
}

is_epoch() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

detect_boot_epoch() {
  if [ "$DEMO" -eq 1 ]; then
    echo "${DEMO_BOOT_TIME:-0}"
  else
    adb_shell cat /proc/stat | awk '$1 == "btime" { print $2; exit }'
  fi
}

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
    adb logcat -b crash -d -v epoch -T "$logcat_since" 2>/dev/null
  fi
}

if [ -z "$CRASH_SINCE" ]; then
  CRASH_SINCE="$(detect_boot_epoch 2>/dev/null || true)"
fi

echo "===== verify dev-sidebar (demo=$DEMO crash_since=${CRASH_SINCE:-unknown}) ====="

# 1) 设备真的起来了
if [ "$(adb_shell getprop sys.boot_completed | tr -d '[:space:]')" == "1" ]; then
  ok "sys.boot_completed = 1"
else
  no "设备未完成启动（sys.boot_completed != 1）"
fi

# 2) system_server 存活
if [ -n "$(adb_shell pidof system_server | tr -d '[:space:]')" ]; then
  ok "system_server 存活"
else
  no "system_server 不在"
fi

# 3) crash buffer 在明确时间窗口内无崩溃；查询失败不能冒充空结果。
if ! is_epoch "$CRASH_SINCE"; then
  no "crash buffer 检查起点无效（since=${CRASH_SINCE:-empty}）"
else
  crash_output=""
  if ! crash_output="$(read_crash_since "$CRASH_SINCE")"; then
    no "crash buffer 查询失败"
  elif [ -n "$(printf '%s\n' "$crash_output" | sed '/^[[:space:]]*$/d')" ]; then
    no "crash buffer 自 $CRASH_SINCE 起发现崩溃"
  else
    ok "crash buffer 自 $CRASH_SINCE 起无崩溃"
  fi
fi

# 4) 新增系统服务 + 边栏 app 存在
if adb_shell service list | grep -q 'sidebar:'; then
  ok "系统服务 sidebar 已注册"
else
  no "service list 未见 sidebar"
fi
if adb_shell pm list packages | grep -q 'com.android.sidebar'; then
  ok "边栏 app com.android.sidebar 已安装"
else
  # feature 早期允许 SKIP，随开发推进转硬断言
  sk "边栏 app 尚未安装（早期可 SKIP）"
fi

echo "-------------------------------------------"
echo "PASS=$pass  FAIL=$fail  SKIP=$skip"
if [ "$fail" -gt 0 ]; then
  echo "RESULT FAIL"
  exit 1
fi
if [ "$skip" -gt 0 ] && [ "$ALLOW_SKIP" -eq 0 ]; then
  echo "RESULT INCOMPLETE"
  exit 1
fi
if [ "$skip" -gt 0 ]; then
  echo "RESULT PASS (SKIP allowed)"
else
  echo "RESULT PASS"
fi
