#!/usr/bin/env bash
# ① 上下文层 · SessionStart fallback：检查当前 feature 与树根软链是否一致。
# 正确性边界是 .claude/bin/claude-feature：它在 Claude 进程启动前完成软链同步。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -L)"
source "$SCRIPT_DIR/feature-common.sh"
ROOT="${CLAUDE_PROJECT_DIR:-$(harness_project_root "$SCRIPT_DIR")}"

use_v1=0
if source "$ROOT/../common/.harness/lib/session-state.sh" 2>/dev/null \
  && [[ "${HARNESS_SESSION_STATE_PROVIDER_VERSION:-}" == 1 ]] \
  && declare -F harness_validate_feature_name harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove >/dev/null; then
  use_v1=1
fi
compat_legacy() { printf '%s\n' 'compat: session-provider=legacy'; }

feature="$(detect_feature "$ROOT" || true)"
target="$(feature_context_path "$ROOT" "$feature" || true)"
if [[ -z "$target" ]]; then
  echo "[load-feature] 未找到当前 feature '${feature:-?}' 的 CLAUDE.md。请退出并用 .claude/bin/claude-feature 启动。" >&2
  cat >/dev/null 2>&1 || true
  exit 0
fi

v1_baseline() {
  local out sid src rc project_id
  out="$(python3 -c '
import json, re, sys
try:
    d = json.load(sys.stdin)
    sid, src = d["session_id"], d["source"]
except Exception:
    sys.exit(1)
if not isinstance(sid, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", sid) or src not in ("startup", "resume", "clear", "compact", "fork"):
    sys.exit(1)
print(sid + "\t" + src)
')" || return 1
  IFS=$'\t' read -r sid src <<<"$out"
  harness_validate_feature_name "$sid" 2>/dev/null || return 1
  project_id="$(realpath -- "$ROOT" | sha256sum)"
  project_id="${project_id%% *}"
  rc=0
  harness_session_state_read "$project_id" "$sid" >/dev/null 2>&1 || rc=$?
  if [[ $rc == 3 && "$src" != compact ]]; then
    rc=0
    harness_session_state_write "$project_id" "$sid" "$feature" >/dev/null 2>&1 || rc=$?
    if [[ $rc == 3 ]]; then echo "error: [load-feature] 会话基线已存在且值不同，未改写。" >&2; elif [[ $rc != 0 ]]; then return 1; fi
  elif [[ $rc == 3 ]]; then
    echo "error: [load-feature] compact 会话基线缺失，未创建。" >&2
  elif [[ $rc != 0 ]]; then
    return 1
  fi
}

if [[ $use_v1 == 1 ]] && v1_baseline; then
  :
else
  compat_legacy
  cat >/dev/null 2>&1 || true
  printf '%s' "$feature" >"${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot"
fi

sync_feature_link "$ROOT" "$target"

if [[ "$FEATURE_LINK_CHANGED" -eq 1 ]]; then
  echo "⚠ [load-feature] SessionStart 才把 CLAUDE.md 切到 $target；本次会话可能已读到旧上下文。请退出并用 .claude/bin/claude-feature 重启。"
else
  echo "[load-feature] 当前 feature=$feature，CLAUDE.md 已由启动 wrapper 预同步。"
fi
