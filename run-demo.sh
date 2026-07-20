#!/bin/bash
# ★ 一键演示三层 harness 如何协同（无需真实 AOSP 树）
#
#   ① 上下文    .claude/bin/claude-feature --dry-run  在 Claude 启动前选定 feature 上下文
#   ① 上下文    check-branch-drift.sh        会话中途切分支告警
#   ② 流程      check-process-layer          离线验证流程 skill 工件与关键命令
#   ③ 验证闭环  verify-sidebar.sh --demo     四步确定性断言
#
# 导航不单独成层：本方案不配 LSP，一律 rg + 源码阅读（理由见 README）。
set -euo pipefail
cd "$(dirname "$0")"

orig="$(cat CURRENT_FEATURE)"
restore_feature() {
  printf '%s\n' "$orig" > CURRENT_FEATURE
}
trap restore_feature EXIT

sep() { echo; echo "############################################################"; echo "# $1"; echo "############################################################"; }

sep "① 上下文：启动 wrapper 在 Claude 进程启动前同步 feature 软链"
./.claude/bin/claude-feature --dry-run
echo "{\"cwd\":\"$PWD\",\"hook_event_name\":\"SessionStart\"}" | .claude/hooks/load-feature.sh
echo
echo "  —— 结果：Claude 启动前，树根 CLAUDE.md 已指向正确 feature ——"
echo "    CLAUDE.md → $(readlink CLAUDE.md)"
echo "    穿软链首个标题: $(grep -m1 '^# ' CLAUDE.md)"
echo "    含各仓约定小节: $(grep -c '^### ' CLAUDE.md) 个（frameworks/base、frameworks/native）"

sep "① 上下文（漂移检测）：模拟会话中途 repo checkout 切了分支"
echo "  [无漂移时] check-branch-drift.sh 零输出："
echo '{}' | .claude/hooks/check-branch-drift.sh
echo "  <上面应无告警>"
echo "  [切到 dev-next 后] 再跑 check-branch-drift.sh："
echo "dev-next" > CURRENT_FEATURE
echo '{}' | .claude/hooks/check-branch-drift.sh
printf '%s\n' "$orig" > CURRENT_FEATURE
echo "  <已还原 CURRENT_FEATURE=$orig>"

sep "① 上下文：涉及仓分支一致性检查（check-branch.sh --demo）"
if ./features/dev-sidebar/check-branch.sh --demo; then
  echo "[demo] 预期样本中的 build/make 漂移，但检查却返回成功。" >&2
  exit 1
else
  echo "[demo] 已按预期识别样本分支漂移。"
fi

sep "② 流程：离线自检编译 / 部署 skill 工件"
./.claude/bin/check-process-layer
echo "[demo] 离线模式验证 skill 的结构和关键流程；实际调用发生在 Claude 会话中。"

sep "③ 验证闭环：verify-sidebar.sh --demo 四步确定性断言"
./features/dev-sidebar/verify-sidebar.sh --demo

sep "回归测试"
./tests/test-harness.sh

sep "三层演示完毕"
echo "对应关系见 README.md『三层与文中章节对应』表。"
