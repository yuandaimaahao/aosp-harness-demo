#!/bin/bash
# ① 上下文层 · UserPromptSubmit hook：会话中途切分支告警
#
#   每条 prompt 跑一次：比对"当前分支"与"注入时 load-feature.sh 记录的快照"。
#   会话中途 repo checkout 切了分支 → 打印一次告警；没切 → 零输出、零打扰。
#
# 真实环境：当前分支读锚定仓链(frameworks/base→native→…) git；DEMO：读 CURRENT_FEATURE。
# 快照路径必须与 load-feature.sh 保持一致（同为 $TMPDIR/.aosp-harness-demo.feature-snapshot）。
# 与真实树的差异：这个单一全局快照文件是教学简化，多个并行会话会互相串写。
# 真实工程用 /tmp/claude-feature-branch-$session_id（session_id 从 hook stdin 的 JSON 里 jq 取），每会话一份——照抄时请按 session_id 隔离。
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/feature-common.sh"

cat >/dev/null 2>&1 || true

cur="$(detect_feature "$ROOT" || true)"

# ---- 注入时快照 ----
snapfile="${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot"
snap=""
[ -f "$snapfile" ] && snap="$(tr -d '[:space:]' < "$snapfile")"

if [ -n "$snap" ] && [ -n "$cur" ] && [ "$cur" != "$snap" ]; then
  echo "⚠️ [分支漂移] 会话注入时在 '$snap'，现在切到了 '$cur'。"
  echo "   当前会话仍含旧上下文；退出后用 .claude/bin/claude-feature 重启，别拿旧分支约定改新分支。"
fi
# 未漂移 → 零输出
