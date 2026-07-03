#!/bin/bash
# ② 上下文层 · UserPromptSubmit hook：会话中途切分支告警
#
#   每条 prompt 跑一次：比对"当前分支"与"注入时 load-feature.sh 记录的快照"。
#   会话中途 repo checkout 切了分支 → 打印一次告警；没切 → 零输出、零打扰。
#
# 真实环境：当前分支读锚定仓链(frameworks/base→native→…) git；DEMO：读 CURRENT_FEATURE。
# 快照路径必须与 load-feature.sh 保持一致（同为 $TMPDIR/.aosp-harness-demo.feature-snapshot）。
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

cat >/dev/null 2>&1 || true

# ---- 当前 feature：与 load-feature.sh 同逻辑（锚定仓链 → CURRENT_FEATURE 回退） ----
cur=""
for repo in frameworks/base frameworks/native system/core; do
  if git -C "$ROOT/$repo" rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
    cur="$(git -C "$ROOT/$repo" rev-parse --abbrev-ref HEAD)"
    break
  fi
done
if [ -z "$cur" ] && [ -f "$ROOT/CURRENT_FEATURE" ]; then
  cur="$(tr -d '[:space:]' < "$ROOT/CURRENT_FEATURE")"
fi

# ---- 注入时快照 ----
snapfile="${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot"
snap=""
[ -f "$snapfile" ] && snap="$(tr -d '[:space:]' < "$snapfile")"

if [ -n "$snap" ] && [ -n "$cur" ] && [ "$cur" != "$snap" ]; then
  echo "⚠️ [分支漂移] 会话注入时在 '$snap'，现在切到了 '$cur'。"
  echo "   先 Read features/$cur/_index.md 拿到新 feature 的上下文，别拿旧分支的约定改新分支。"
fi
# 未漂移 → 零输出
