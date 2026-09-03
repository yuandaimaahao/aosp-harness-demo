#!/usr/bin/env bash
# ① 上下文层 · UserPromptSubmit：会话中途切分支后持续告警。
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
cur="$(detect_feature "$ROOT" || true)"
v1_drift() {
  local sid rc project_id snap
  sid="$(python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    sid = d["session_id"]
except Exception:
    sys.exit(1)
if not isinstance(sid, str):
    sys.exit(1)
print(sid)
')" || return 1
  harness_validate_feature_name "$sid" 2>/dev/null || return 1
  project_id="$(realpath -- "$ROOT" | sha256sum)"
  project_id="${project_id%% *}"
  rc=0
  snap="$(harness_session_state_read "$project_id" "$sid" 2>/dev/null)" || rc=$?
  [[ $rc == 3 ]] && exit 0
  [[ $rc == 0 ]] || return 1
  if [[ -n "$snap" && -n "$cur" && "$cur" != "$snap" ]]; then
    echo "⚠️ [分支漂移] 会话注入时在 '$snap'，现在切到了 '$cur'。"
    echo "   当前会话仍含旧上下文；退出后用 .claude/bin/claude-feature 重启，别拿旧分支约定改新分支。"
    exit 2
  fi
  exit 0
}
[[ $use_v1 == 1 ]] && v1_drift || true
compat_legacy
cat >/dev/null 2>&1 || true
snapfile="${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot"
snap=""
[[ -f "$snapfile" ]] && snap="$(tr -d '[:space:]' <"$snapfile")"

if [[ -n "$snap" && -n "$cur" && "$cur" != "$snap" ]]; then
  echo "⚠️ [分支漂移] 会话注入时在 '$snap'，现在切到了 '$cur'。"
  echo "   当前会话仍含旧上下文；退出后用 .claude/bin/claude-feature 重启，别拿旧分支约定改新分支。"
fi
