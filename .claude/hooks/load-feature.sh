#!/bin/bash
# ① 上下文层 · SessionStart fallback：检查当前 feature 与树根软链是否一致。
# 正确性边界是 .claude/bin/claude-feature：它在 Claude 进程启动前完成软链同步。
#
# 真实环境：锚定仓(frameworks/base→native→…)读当前 git 分支；编辑穿软链直达 feature 文件、落 features/ 仓。
# DEMO：无真实 repo 树，分支读 CURRENT_FEATURE。根 CLAUDE.md 提交成指向 feature 单文件的软链，hook 幂等重指。
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/feature-common.sh"
cat >/dev/null 2>&1 || true   # 读掉 stdin 的 JSON，避免管道阻塞

feature="$(detect_feature "$ROOT" || true)"
target="$(feature_context_path "$ROOT" "$feature" || true)"
if [[ -z "$target" ]]; then
  echo "[load-feature] 未找到当前 feature '${feature:-?}' 的 CLAUDE.md。请退出并用 .claude/bin/claude-feature 启动。" >&2
  exit 0
fi

# ---- 记录快照，供 UserPromptSubmit 的漂移检测比对 ----
# 与真实树的差异：这里为教学简化用了单一全局快照文件，多个并行会话会互相串写。
# 真实工程用 /tmp/claude-feature-branch-$session_id（session_id 从 hook stdin 的 JSON 里 jq 取），每会话一份——照抄时请按 session_id 隔离。
printf '%s' "$feature" > "${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot"

sync_feature_link "$ROOT" "$target"

if [[ "$FEATURE_LINK_CHANGED" -eq 1 ]]; then
  echo "⚠ [load-feature] SessionStart 才把 CLAUDE.md 切到 $target；本次会话可能已读到旧上下文。请退出并用 .claude/bin/claude-feature 重启。"
else
  echo "[load-feature] 当前 feature=$feature，CLAUDE.md 已由启动 wrapper 预同步。"
fi
