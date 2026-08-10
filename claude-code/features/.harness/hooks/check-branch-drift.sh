#!/usr/bin/env bash
# ① 上下文层 · UserPromptSubmit：会话中途切分支后持续告警。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -L)"
source "$SCRIPT_DIR/feature-common.sh"
ROOT="${CLAUDE_PROJECT_DIR:-$(harness_project_root "$SCRIPT_DIR")}"
cat >/dev/null 2>&1 || true

cur="$(detect_feature "$ROOT" || true)"
snapfile="${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot"
snap=""
[[ -f "$snapfile" ]] && snap="$(tr -d '[:space:]' < "$snapfile")"

if [[ -n "$snap" && -n "$cur" && "$cur" != "$snap" ]]; then
  echo "⚠️ [分支漂移] 会话注入时在 '$snap'，现在切到了 '$cur'。"
  echo "   当前会话仍含旧上下文；退出后用 .claude/bin/claude-feature 重启，别拿旧分支约定改新分支。"
fi
