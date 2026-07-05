#!/bin/bash
# ★ 一键演示四层 harness 如何协同（无需真实 AOSP 树）
#
#   ① 代码智能  gen-compdb-clangd.sh --demo  两段式精简 compdb
#   ② 上下文    load-feature.sh              SessionStart 把树根 CLAUDE.md 软链重指到 feature 单文件
#   ② 上下文    check-branch-drift.sh        会话中途切分支告警
#   ④ 护栏验证  verify-sidebar.sh --demo     四步确定性断言
set -uo pipefail
cd "$(dirname "$0")"

sep() { echo; echo "############################################################"; echo "# $1"; echo "############################################################"; }

sep "① 代码智能：两段式 compdb 精简（全树库 → feature 精简库）"
./gen-compdb-clangd.sh --demo

sep "② 上下文（v2 软链单文件）：模拟 Claude Code 启动，触发 load-feature.sh 把树根 CLAUDE.md 软链重指到 feature 单文件"
echo "{\"cwd\":\"$PWD\",\"hook_event_name\":\"SessionStart\"}" | .claude/hooks/load-feature.sh
echo
echo "  —— 结果：树根 CLAUDE.md 是指向 feature 单文件的软链，启动即整份(树级+总览+各仓约定)进持久上下文 ——"
echo "    CLAUDE.md → $(readlink CLAUDE.md)"
echo "    穿软链首个标题: $(grep -m1 '^# ' CLAUDE.md)"
echo "    含各仓约定小节: $(grep -c '^### ' CLAUDE.md) 个（frameworks/base、frameworks/native）"

sep "② 上下文（漂移检测）：模拟会话中途 repo checkout 切了分支"
orig="$(cat CURRENT_FEATURE)"
echo "  [无漂移时] check-branch-drift.sh 零输出："
echo '{}' | .claude/hooks/check-branch-drift.sh
echo "  <上面应无告警>"
echo "  [切到 dev-next 后] 再跑 check-branch-drift.sh："
echo "dev-next" > CURRENT_FEATURE
echo '{}' | .claude/hooks/check-branch-drift.sh
printf '%s\n' "$orig" > CURRENT_FEATURE          # 还原
echo "  <已还原 CURRENT_FEATURE=$orig>"

sep "② 上下文：涉及仓分支一致性检查（check-branch.sh --demo）"
./features/dev-sidebar/check-branch.sh --demo

sep "④ 护栏与验证：verify-sidebar.sh --demo 四步确定性断言"
./features/dev-sidebar/verify-sidebar.sh --demo

sep "四层演示完毕"
echo "对应关系见 README.md『四层与文中章节对应』表。"
