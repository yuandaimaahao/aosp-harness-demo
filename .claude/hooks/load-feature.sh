#!/bin/bash
# ② 上下文层 · SessionStart hook（v2 软链单文件）：定当前 feature → 把树根 CLAUDE.md 软链重指到
#   features/<分支>/CLAUDE.md → 一行 banner + 记漂移快照。只动树根一个软链，不碰任何仓、不写任何 gerrit 工作区。
#
# 真实环境：锚定仓(frameworks/base→native→…)读当前 git 分支；编辑穿软链直达 feature 文件、落 features/ 仓。
# DEMO：无真实 repo 树，分支读 CURRENT_FEATURE。根 CLAUDE.md 提交成指向 feature 单文件的软链，hook 幂等重指。
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cat >/dev/null 2>&1 || true   # 读掉 stdin 的 JSON，避免管道阻塞

# ---- 当前 feature：优先有独立 .git 的锚定仓（真实树），否则回退 CURRENT_FEATURE（demo） ----
feature=""
for repo in frameworks/base frameworks/native system/core; do
  [ -e "$ROOT/$repo/.git" ] || continue
  if b="$(git -C "$ROOT/$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)"; then feature="$b"; break; fi
done
if [ -z "$feature" ] && [ -f "$ROOT/CURRENT_FEATURE" ]; then
  feature="$(tr -d '[:space:]' < "$ROOT/CURRENT_FEATURE")"
fi

feat="features/$feature/CLAUDE.md"
if [ -z "$feature" ] || [ ! -f "$ROOT/$feat" ]; then
  echo "[load-feature] 未找到 $feat（feature='${feature:-?}'），根 CLAUDE.md 未改。" >&2
  exit 0
fi

# ---- 记录快照，供 UserPromptSubmit 的漂移检测比对 ----
echo "$feature" > "${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot"

# ---- 核心：把树根 CLAUDE.md 软链重指到本 feature 的单文件（根若为真实文件先备份，防误删内容） ----
if [ -e "$ROOT/CLAUDE.md" ] && [ ! -L "$ROOT/CLAUDE.md" ]; then
  cp -a "$ROOT/CLAUDE.md" "$ROOT/CLAUDE.md.bak.$(date +%s)" 2>/dev/null || true
fi
ln -sfn "$feat" "$ROOT/CLAUDE.md"

echo "===== [SessionStart · v2 软链单文件] 根 CLAUDE.md → $feat（feature=$feature） ====="
echo "[load-feature] 根软链已重指；启动时 Claude Code 穿软链把该 feature 全部上下文"
echo "               (树级 bootstrap/硬约束 + 总览 + 各仓约定) 载入 Memory files 持久桶，长会话不掉、子代理也吃到。"
echo "[load-feature] 编辑根 CLAUDE.md = 编辑 $feat（软链直达）→ 落 features/ 仓，提交手动。"
