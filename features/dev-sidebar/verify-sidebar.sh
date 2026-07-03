#!/bin/bash
# ④ 护栏与验证层：dev-sidebar 的确定性验证脚本 —— 就是这个 feature 的"测试"
#
#   输出只有确定性的 PASS / FAIL / SKIP（中间态会诱导 agent 把模糊输出读成成功）。
#   四步断言：设备起来了 → system_server 存活 → 无新增 crash → 新服务/新 app 存在。
#
# 用法：
#   ./verify-sidebar.sh          # 真实模式：走 adb 断言（adb 命中 permissions.ask 弹窗）
#   ./verify-sidebar.sh --demo   # DEMO 模式：无设备，用样本输出演示 PASS/SKIP
set -uo pipefail

DEMO=0
[ "${1:-}" == "--demo" ] && DEMO=1

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
      "logcat -b crash -d")              echo "" ;;   # 无新增崩溃
      "service list")                    echo "52  sidebar: [android.sidebar.ISidebar]" ;;
      "pm list packages")               echo "package:com.android.sidebar" ;;
      *)                                  echo "" ;;
    esac
  else
    adb shell "$@" 2>/dev/null
  fi
}

echo "===== verify dev-sidebar (demo=$DEMO) ====="

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

# 3) crash buffer 无新增崩溃
if [ -z "$(adb_shell logcat -b crash -d | grep -i 'FATAL\|beginning of crash' || true)" ]; then
  ok "crash buffer 无新增崩溃"
else
  no "crash buffer 有崩溃记录"
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
[ $fail -eq 0 ]   # FAIL>0 → 非零退出，斩断"编过=改对"
