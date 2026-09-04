# review 包 cc04996e..4ceca2bf

## commit 列表

```
4ceca2b feat(claude): route session hooks through provider guard
```

## diff --stat

```
 .../features/.harness/hooks/check-branch-drift.sh  | 41 ++++++++++++++++--
 .../features/.harness/hooks/load-feature.sh        | 48 ++++++++++++++++++++--
 claude-code/features/.harness/hooks/session-end.sh | 45 ++++++++++++++++++++
 claude-code/features/.harness/settings.json        |  3 ++
 4 files changed, 131 insertions(+), 6 deletions(-)
```

## diff

```diff
diff --git a/claude-code/features/.harness/hooks/check-branch-drift.sh b/claude-code/features/.harness/hooks/check-branch-drift.sh
index d712e68..b126871 100755
--- a/claude-code/features/.harness/hooks/check-branch-drift.sh
+++ b/claude-code/features/.harness/hooks/check-branch-drift.sh
@@ -1,18 +1,53 @@
 #!/usr/bin/env bash
 # ① 上下文层 · UserPromptSubmit：会话中途切分支后持续告警。
 set -euo pipefail
 
 SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -L)"
 source "$SCRIPT_DIR/feature-common.sh"
 ROOT="${CLAUDE_PROJECT_DIR:-$(harness_project_root "$SCRIPT_DIR")}"
-cat >/dev/null 2>&1 || true
-
+use_v1=0
+if source "$ROOT/../common/.harness/lib/session-state.sh" 2>/dev/null \
+  && [[ "${HARNESS_SESSION_STATE_PROVIDER_VERSION:-}" == 1 ]] \
+  && declare -F harness_validate_feature_name harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove >/dev/null; then
+  use_v1=1
+fi
+compat_legacy() { printf '%s\n' 'compat: session-provider=legacy'; }
 cur="$(detect_feature "$ROOT" || true)"
+v1_drift() {
+  local sid rc project_id snap
+  sid="$(python3 -c '
+import json, sys
+try:
+    d = json.load(sys.stdin)
+    sid = d["session_id"]
+except Exception:
+    sys.exit(1)
+if not isinstance(sid, str):
+    sys.exit(1)
+print(sid)
+')" || return 1
+  harness_validate_feature_name "$sid" 2>/dev/null || return 1
+  project_id="$(realpath -- "$ROOT" | sha256sum)"
+  project_id="${project_id%% *}"
+  rc=0
+  snap="$(harness_session_state_read "$project_id" "$sid" 2>/dev/null)" || rc=$?
+  [[ $rc == 3 ]] && exit 0
+  [[ $rc == 0 ]] || return 1
+  if [[ -n "$snap" && -n "$cur" && "$cur" != "$snap" ]]; then
+    echo "⚠️ [分支漂移] 会话注入时在 '$snap'，现在切到了 '$cur'。"
+    echo "   当前会话仍含旧上下文；退出后用 .claude/bin/claude-feature 重启，别拿旧分支约定改新分支。"
+    exit 2
+  fi
+  exit 0
+}
+[[ $use_v1 == 1 ]] && v1_drift || true
+compat_legacy
+cat >/dev/null 2>&1 || true
 snapfile="${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot"
 snap=""
-[[ -f "$snapfile" ]] && snap="$(tr -d '[:space:]' < "$snapfile")"
+[[ -f "$snapfile" ]] && snap="$(tr -d '[:space:]' <"$snapfile")"
 
 if [[ -n "$snap" && -n "$cur" && "$cur" != "$snap" ]]; then
   echo "⚠️ [分支漂移] 会话注入时在 '$snap'，现在切到了 '$cur'。"
   echo "   当前会话仍含旧上下文；退出后用 .claude/bin/claude-feature 重启，别拿旧分支约定改新分支。"
 fi
diff --git a/claude-code/features/.harness/hooks/load-feature.sh b/claude-code/features/.harness/hooks/load-feature.sh
index 17bd013..d0b125a 100755
--- a/claude-code/features/.harness/hooks/load-feature.sh
+++ b/claude-code/features/.harness/hooks/load-feature.sh
@@ -1,27 +1,69 @@
 #!/usr/bin/env bash
 # ① 上下文层 · SessionStart fallback：检查当前 feature 与树根软链是否一致。
 # 正确性边界是 .claude/bin/claude-feature：它在 Claude 进程启动前完成软链同步。
 set -euo pipefail
 
 SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -L)"
 source "$SCRIPT_DIR/feature-common.sh"
 ROOT="${CLAUDE_PROJECT_DIR:-$(harness_project_root "$SCRIPT_DIR")}"
-cat >/dev/null 2>&1 || true
+
+use_v1=0
+if source "$ROOT/../common/.harness/lib/session-state.sh" 2>/dev/null \
+  && [[ "${HARNESS_SESSION_STATE_PROVIDER_VERSION:-}" == 1 ]] \
+  && declare -F harness_validate_feature_name harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove >/dev/null; then
+  use_v1=1
+fi
+compat_legacy() { printf '%s\n' 'compat: session-provider=legacy'; }
 
 feature="$(detect_feature "$ROOT" || true)"
 target="$(feature_context_path "$ROOT" "$feature" || true)"
 if [[ -z "$target" ]]; then
   echo "[load-feature] 未找到当前 feature '${feature:-?}' 的 CLAUDE.md。请退出并用 .claude/bin/claude-feature 启动。" >&2
   exit 0
 fi
 
-# Demo 为教学简化使用单一快照；真实多会话环境应按 hook JSON 的 session_id 隔离。
-printf '%s' "$feature" > "${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot"
+v1_baseline() {
+  local out sid src rc project_id
+  out="$(python3 -c '
+import json, sys
+try:
+    d = json.load(sys.stdin)
+    sid, src = d["session_id"], d["source"]
+except Exception:
+    sys.exit(1)
+if not isinstance(sid, str) or src not in ("startup", "resume", "clear", "compact", "fork"):
+    sys.exit(1)
+print(sid + "\t" + src)
+')" || return 1
+  IFS=$'\t' read -r sid src <<<"$out"
+  harness_validate_feature_name "$sid" 2>/dev/null || return 1
+  project_id="$(realpath -- "$ROOT" | sha256sum)"
+  project_id="${project_id%% *}"
+  rc=0
+  harness_session_state_read "$project_id" "$sid" >/dev/null 2>&1 || rc=$?
+  if [[ $rc == 3 && "$src" != compact ]]; then
+    rc=0
+    harness_session_state_write "$project_id" "$sid" "$feature" >/dev/null 2>&1 || rc=$?
+    [[ $rc == 0 || $rc == 3 ]] || return 1
+  elif [[ $rc == 3 ]]; then
+    echo "error: [load-feature] compact 会话基线缺失，未创建。" >&2
+  elif [[ $rc != 0 ]]; then
+    return 1
+  fi
+}
+
+if [[ $use_v1 == 1 ]] && v1_baseline; then
+  :
+else
+  compat_legacy
+  cat >/dev/null 2>&1 || true
+  printf '%s' "$feature" >"${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot"
+fi
 
 sync_feature_link "$ROOT" "$target"
 
 if [[ "$FEATURE_LINK_CHANGED" -eq 1 ]]; then
   echo "⚠ [load-feature] SessionStart 才把 CLAUDE.md 切到 $target；本次会话可能已读到旧上下文。请退出并用 .claude/bin/claude-feature 重启。"
 else
   echo "[load-feature] 当前 feature=$feature，CLAUDE.md 已由启动 wrapper 预同步。"
 fi
diff --git a/claude-code/features/.harness/hooks/session-end.sh b/claude-code/features/.harness/hooks/session-end.sh
new file mode 100644
index 0000000..7efafb6
--- /dev/null
+++ b/claude-code/features/.harness/hooks/session-end.sh
@@ -0,0 +1,45 @@
+#!/usr/bin/env bash
+# ① 上下文层 · SessionEnd：校验事件名/session ID/reason 后幂等清理已提交状态。
+set -euo pipefail
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -L)"
+source "$SCRIPT_DIR/feature-common.sh"
+ROOT="${CLAUDE_PROJECT_DIR:-$(harness_project_root "$SCRIPT_DIR")}"
+
+use_v1=0
+if source "$ROOT/../common/.harness/lib/session-state.sh" 2>/dev/null \
+  && [[ "${HARNESS_SESSION_STATE_PROVIDER_VERSION:-}" == 1 ]] \
+  && declare -F harness_validate_feature_name harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove >/dev/null; then
+  use_v1=1
+fi
+compat_legacy() { printf '%s\n' 'compat: session-provider=legacy'; }
+
+sid="$(python3 -c '
+import json, re, sys
+try:
+    d = json.load(sys.stdin)
+    ev, sid, reason = d["hook_event_name"], d["session_id"], d["reason"]
+except Exception:
+    sys.exit(1)
+if (ev != "SessionEnd" or not isinstance(sid, str)
+        or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", sid)
+        or reason not in ("clear", "resume", "logout", "prompt_input_exit", "other")):
+    sys.exit(1)
+print(sid)
+')" || sid=""
+
+if [[ -z "$sid" ]]; then
+  compat_legacy
+  exit 0
+fi
+
+if [[ $use_v1 == 1 ]]; then
+  project_id="$(realpath -- "$ROOT" | sha256sum)"
+  project_id="${project_id%% *}"
+  rc=0
+  harness_session_state_remove "$project_id" "$sid" >/dev/null 2>&1 || rc=$?
+  [[ $rc == 0 ]] || compat_legacy
+else
+  compat_legacy
+  rm -f -- "${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot" 2>/dev/null || true
+fi
diff --git a/claude-code/features/.harness/settings.json b/claude-code/features/.harness/settings.json
index cc7013f..160346e 100644
--- a/claude-code/features/.harness/settings.json
+++ b/claude-code/features/.harness/settings.json
@@ -1,11 +1,14 @@
 {
   "//": "DEMO —— 公共 Harness 的物理位置是 features/.harness；树根 .claude 软链负责标准路径暴露",
   "hooks": {
     "SessionStart": [
       { "hooks": [ { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/load-feature.sh" } ] }
     ],
     "UserPromptSubmit": [
       { "hooks": [ { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/check-branch-drift.sh" } ] }
+    ],
+    "SessionEnd": [
+      { "hooks": [ { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/session-end.sh" } ] }
     ]
   }
 }
```
