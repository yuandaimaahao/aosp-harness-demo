#!/bin/bash
# ② 上下文层 · SessionStart hook：按当前分支注入 feature 上下文
#
# 真实环境：从 stdin 的 JSON 拿 cwd → 到锚定仓(frameworks/base→native→…)读当前 git 分支
#           → cat features/<分支>/_index.md 到 stdout（Claude Code 注入为会话上下文）。
# DEMO：没有真实 repo 树，改为读树根的 CURRENT_FEATURE 文件来模拟"锚定仓当前分支"。
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

# ---- 读 stdin 的 JSON（真实 hook 会用到 cwd；demo 里读掉即可，避免管道阻塞） ----
cat >/dev/null 2>&1 || true

# ---- 确定当前 feature（= repo 分支名） ----
feature=""
# 真实环境：按锚定仓链读分支
for repo in frameworks/base frameworks/native system/core; do
  if git -C "$ROOT/$repo" rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
    feature="$(git -C "$ROOT/$repo" rev-parse --abbrev-ref HEAD)"
    break
  fi
done
# DEMO 回退：读 CURRENT_FEATURE 文件
if [ -z "$feature" ] && [ -f "$ROOT/CURRENT_FEATURE" ]; then
  feature="$(tr -d '[:space:]' < "$ROOT/CURRENT_FEATURE")"
fi

index="$ROOT/features/$feature/_index.md"
if [ -z "$feature" ] || [ ! -f "$index" ]; then
  echo "[load-feature] 未找到当前 feature 的索引（feature='${feature:-?}'），跳过注入。" >&2
  exit 0
fi

# ---- 记录快照，供 UserPromptSubmit 的漂移检测比对 ----
echo "$feature" > "${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot"

# ---- 把索引打印到 stdout：Claude Code 会将其注入为会话上下文 ----
echo "===== [SessionStart 注入] 当前 feature = $feature ====="
cat "$index"
