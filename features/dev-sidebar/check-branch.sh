#!/bin/bash
# ② 上下文层：涉及仓分支一致性检查
#
#   一个 feature = 一个 repo 本地分支，全部涉及仓都应在同一分支上。
#   本脚本挨个进涉及仓看当前 git 分支是否 = feature 名，不一致就报警。
#
# 真实工程：对每个仓 `git -C <repo> rev-parse --abbrev-ref HEAD`。
# DEMO：无 AOSP 树，用 CURRENT_FEATURE 模拟"应在的分支"，仓状态用样本数据演示。
set -euo pipefail
cd "$(dirname "$0")/../.."

FEATURE="dev-sidebar"
REPOS=("frameworks/base" "frameworks/native" "packages/apps/SidebarApp" "build/make" "system/sepolicy")

if [ "${1:-}" == "--demo" ]; then
  # 样本：故意让 build/make 落在别的分支，演示报警
  declare -A DEMO_BRANCH=(
    ["frameworks/base"]="dev-sidebar"
    ["frameworks/native"]="dev-sidebar"
    ["packages/apps/SidebarApp"]="dev-sidebar"
    ["build/make"]="main"
    ["system/sepolicy"]="dev-sidebar"
  )
  bad=0
  for r in "${REPOS[@]}"; do
    b="${DEMO_BRANCH[$r]}"
    if [ "$b" == "$FEATURE" ]; then
      echo "OK   $r @ $b"
    else
      echo "DRIFT $r @ $b  (应为 $FEATURE)"; bad=1
    fi
  done
  [ $bad -eq 0 ] && echo "[demo] 全部涉及仓一致" || echo "[demo] 有仓不在 $FEATURE 分支，先 repo checkout 对齐再动手"
  exit 0
fi

# ---- 真实模式 ----
bad=0
for r in "${REPOS[@]}"; do
  if [ ! -d "$r/.git" ]; then echo "SKIP $r（非 git 仓或不存在）"; continue; fi
  b="$(git -C "$r" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  if [ "$b" == "$FEATURE" ]; then echo "OK   $r @ $b"; else echo "DRIFT $r @ $b (应为 $FEATURE)"; bad=1; fi
done
exit $bad
