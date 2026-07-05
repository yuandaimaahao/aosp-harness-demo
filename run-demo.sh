#!/bin/bash
# ★ 一键演示四层 harness 如何协同（无需真实 AOSP 树）
#
#   ① 代码智能  gen-compdb-clangd.sh --demo  两段式精简 compdb
#   ② 上下文    load-feature.sh              SessionStart 注入 feature 索引
#   ② 上下文    check-branch-drift.sh        会话中途切分支告警
#   ④ 护栏验证  verify-sidebar.sh --demo     四步确定性断言
set -uo pipefail
cd "$(dirname "$0")"

sep() { echo; echo "############################################################"; echo "# $1"; echo "############################################################"; }

sep "① 代码智能：两段式 compdb 精简（全树库 → feature 精简库）"
./gen-compdb-clangd.sh --demo

sep "② 上下文（SessionStart 注入 + 物化各仓 CLAUDE.md）：模拟 Claude Code 启动，触发 load-feature.sh"
echo "{\"cwd\":\"$PWD\",\"hook_event_name\":\"SessionStart\"}" | .claude/hooks/load-feature.sh
echo
echo "  —— 物化产物：各仓根出现 CLAUDE.md（编辑该仓文件时 Claude Code 按需加载该仓约定）——"
for r in frameworks/base frameworks/native; do
  [ -f "$r/CLAUDE.md" ] && echo "    $r/CLAUDE.md  ← $(head -n1 "$r/CLAUDE.md")"
done

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
