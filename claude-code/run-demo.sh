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

DEMO_TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/claude-harness-demo.XXXXXX")
trap 'rm -rf -- "$DEMO_TMP_DIR"' EXIT

sep() {
  echo
  echo "############################################################"
  echo "# $1"
  echo "############################################################"
}

sep "① 上下文：安装器暴露版本化公共 Harness"
./features/install-harness.sh
echo "    .claude → $(readlink .claude)"

sep "① 上下文：启动 wrapper 在 Claude 进程启动前同步 feature 软链"
./.claude/bin/claude-feature --dry-run
echo
echo "  —— 结果：Claude 启动前，树根 CLAUDE.md 已指向正确 feature ——"
echo "    CLAUDE.md → $(readlink CLAUDE.md)"
echo "    穿软链首个标题: $(grep -m1 '^# ' CLAUDE.md)"
echo "    含各仓约定小节: $(grep -c '^### ' CLAUDE.md) 个（frameworks/base、frameworks/native）"

sep "① 上下文（会话生命周期）：私有 fixture 演示 v1 SessionStart/UserPromptSubmit/SessionEnd"
tree="$DEMO_TMP_DIR/tree"
mkdir -p "$tree/claude-code/features/dev-sidebar" "$tree/claude-code/features/dev-next" \
  "$tree/common/.harness/lib" "$DEMO_TMP_DIR/tmp"
printf '%s\n' dev-sidebar >"$tree/claude-code/CURRENT_FEATURE"
printf '%s\n' '# demo context: dev-sidebar' >"$tree/claude-code/features/dev-sidebar/CLAUDE.md"
printf '%s\n' '# demo context: dev-next' >"$tree/claude-code/features/dev-next/CLAUDE.md"
cp ../common/.harness/lib/session-state*.sh "$tree/common/.harness/lib/"
hook() {
  CLAUDE_PROJECT_DIR="$tree/claude-code" TMPDIR="$DEMO_TMP_DIR/tmp" \
    HARNESS_STATE_ROOT="$DEMO_TMP_DIR/state" "./.claude/hooks/$1.sh"
}

echo '{"session_id":"demo-session","source":"startup","hook_event_name":"SessionStart"}' | hook load-feature
echo "  [state 树] $(find "$DEMO_TMP_DIR/state" -type f | sort)"
echo "  [无漂移时] check-branch-drift.sh 零输出："
echo '{"session_id":"demo-session"}' | hook check-branch-drift
echo "  <上面应无告警>"
printf '%s\n' dev-next >"$tree/claude-code/CURRENT_FEATURE"
echo "  [切到 dev-next 后] 再跑 check-branch-drift.sh（受控失败演示：期望 exit 2 阻止 prompt）："
set +e
echo '{"session_id":"demo-session"}' | hook check-branch-drift
drift_rc=$?
set -e
if [[ "$drift_rc" -ne 2 ]]; then
  echo "[demo] error: 漂移未按预期返回 exit 2（实际 $drift_rc）" >&2
  exit 1
fi
echo "[demo] 已按预期以 exit 2 阻止该 prompt；私有 fixture 之外的真实 CURRENT_FEATURE 始终只读。"
echo '{"session_id":"demo-session","hook_event_name":"SessionEnd","reason":"clear"}' | hook session-end
echo "  [SessionEnd 清理后 state 树] $(find "$DEMO_TMP_DIR/state" -type f 2>/dev/null | sort)（应为空）"

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
./.claude/tests/test-harness.sh

sep "三层演示完毕"
echo "对应关系见 README.md『三层与文中章节对应』表。"
