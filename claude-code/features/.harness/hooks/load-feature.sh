#!/usr/bin/env bash
# ① 上下文层 · SessionStart fallback：检查当前 feature 与树根软链是否一致。
# 正确性边界是 .claude/bin/claude-feature：它在 Claude 进程启动前完成软链同步。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -L)"
source "$SCRIPT_DIR/feature-common.sh"
ROOT="${CLAUDE_PROJECT_DIR:-$(harness_project_root "$SCRIPT_DIR")}"
cat >/dev/null 2>&1 || true

feature="$(detect_feature "$ROOT" || true)"
target="$(feature_context_path "$ROOT" "$feature" || true)"
if [[ -z "$target" ]]; then
  echo "[load-feature] 未找到当前 feature '${feature:-?}' 的 CLAUDE.md。请退出并用 .claude/bin/claude-feature 启动。" >&2
  exit 0
fi

# Demo 为教学简化使用单一快照；真实多会话环境应按 hook JSON 的 session_id 隔离。
printf '%s' "$feature" > "${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot"

sync_feature_link "$ROOT" "$target"

if [[ "$FEATURE_LINK_CHANGED" -eq 1 ]]; then
  echo "⚠ [load-feature] SessionStart 才把 CLAUDE.md 切到 $target；本次会话可能已读到旧上下文。请退出并用 .claude/bin/claude-feature 重启。"
else
  echo "[load-feature] 当前 feature=$feature，CLAUDE.md 已由启动 wrapper 预同步。"
fi
