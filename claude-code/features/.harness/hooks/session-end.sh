#!/usr/bin/env bash
# ① 上下文层 · SessionEnd：校验事件名/session ID/reason 后幂等清理已提交状态。
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

sid="$(python3 -c '
import json, re, sys
try:
    d = json.load(sys.stdin)
    ev, sid, reason = d["hook_event_name"], d["session_id"], d["reason"]
except Exception:
    sys.exit(1)
if (ev != "SessionEnd" or not isinstance(sid, str)
        or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", sid)
        or reason not in ("clear", "resume", "logout", "prompt_input_exit", "other")):
    sys.exit(1)
print(sid)
')" || sid=""

if [[ -z "$sid" ]]; then
  compat_legacy
  exit 0
fi

if [[ $use_v1 == 1 ]]; then
  project_id="$(realpath -- "$ROOT" | sha256sum)"
  project_id="${project_id%% *}"
  rc=0
  harness_session_state_remove "$project_id" "$sid" >/dev/null 2>&1 || rc=$?
  [[ $rc == 0 ]] || compat_legacy
else
  compat_legacy
  rm -f -- "${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot" 2>/dev/null || true
fi
