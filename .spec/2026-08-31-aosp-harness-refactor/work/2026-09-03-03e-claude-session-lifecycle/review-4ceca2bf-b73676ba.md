# review 包 4ceca2bf..b73676ba

## commit 列表

```
b73676b fix(claude): close session-id truncation and legacy-cleanup gaps in hooks
```

## diff --stat

```
 claude-code/features/.harness/hooks/check-branch-drift.sh |  6 +++---
 claude-code/features/.harness/hooks/load-feature.sh       |  7 ++++---
 claude-code/features/.harness/hooks/session-end.sh        | 10 ++++++----
 3 files changed, 13 insertions(+), 10 deletions(-)
```

## diff

```diff
diff --git a/claude-code/features/.harness/hooks/check-branch-drift.sh b/claude-code/features/.harness/hooks/check-branch-drift.sh
index b126871..324897c 100755
--- a/claude-code/features/.harness/hooks/check-branch-drift.sh
+++ b/claude-code/features/.harness/hooks/check-branch-drift.sh
@@ -9,45 +9,45 @@ use_v1=0
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
-import json, sys
+import json, re, sys
 try:
     d = json.load(sys.stdin)
     sid = d["session_id"]
 except Exception:
     sys.exit(1)
-if not isinstance(sid, str):
+if not isinstance(sid, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", sid):
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
-[[ $use_v1 == 1 ]] && v1_drift || true
+if [[ $use_v1 == 1 ]] && v1_drift; then :; fi
 compat_legacy
 cat >/dev/null 2>&1 || true
 snapfile="${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot"
 snap=""
 [[ -f "$snapfile" ]] && snap="$(tr -d '[:space:]' <"$snapfile")"
 
 if [[ -n "$snap" && -n "$cur" && "$cur" != "$snap" ]]; then
   echo "⚠️ [分支漂移] 会话注入时在 '$snap'，现在切到了 '$cur'。"
   echo "   当前会话仍含旧上下文；退出后用 .claude/bin/claude-feature 重启，别拿旧分支约定改新分支。"
 fi
diff --git a/claude-code/features/.harness/hooks/load-feature.sh b/claude-code/features/.harness/hooks/load-feature.sh
index d0b125a..d4681bc 100755
--- a/claude-code/features/.harness/hooks/load-feature.sh
+++ b/claude-code/features/.harness/hooks/load-feature.sh
@@ -12,46 +12,47 @@ if source "$ROOT/../common/.harness/lib/session-state.sh" 2>/dev/null \
   && [[ "${HARNESS_SESSION_STATE_PROVIDER_VERSION:-}" == 1 ]] \
   && declare -F harness_validate_feature_name harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove >/dev/null; then
   use_v1=1
 fi
 compat_legacy() { printf '%s\n' 'compat: session-provider=legacy'; }
 
 feature="$(detect_feature "$ROOT" || true)"
 target="$(feature_context_path "$ROOT" "$feature" || true)"
 if [[ -z "$target" ]]; then
   echo "[load-feature] 未找到当前 feature '${feature:-?}' 的 CLAUDE.md。请退出并用 .claude/bin/claude-feature 启动。" >&2
+  cat >/dev/null 2>&1 || true
   exit 0
 fi
 
 v1_baseline() {
   local out sid src rc project_id
   out="$(python3 -c '
-import json, sys
+import json, re, sys
 try:
     d = json.load(sys.stdin)
     sid, src = d["session_id"], d["source"]
 except Exception:
     sys.exit(1)
-if not isinstance(sid, str) or src not in ("startup", "resume", "clear", "compact", "fork"):
+if not isinstance(sid, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", sid) or src not in ("startup", "resume", "clear", "compact", "fork"):
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
-    [[ $rc == 0 || $rc == 3 ]] || return 1
+    if [[ $rc == 3 ]]; then echo "error: [load-feature] 会话基线已存在且值不同，未改写。" >&2; elif [[ $rc != 0 ]]; then return 1; fi
   elif [[ $rc == 3 ]]; then
     echo "error: [load-feature] compact 会话基线缺失，未创建。" >&2
   elif [[ $rc != 0 ]]; then
     return 1
   fi
 }
 
 if [[ $use_v1 == 1 ]] && v1_baseline; then
   :
 else
diff --git a/claude-code/features/.harness/hooks/session-end.sh b/claude-code/features/.harness/hooks/session-end.sh
old mode 100644
new mode 100755
index 7efafb6..786cd2b
--- a/claude-code/features/.harness/hooks/session-end.sh
+++ b/claude-code/features/.harness/hooks/session-end.sh
@@ -7,38 +7,40 @@ source "$SCRIPT_DIR/feature-common.sh"
 ROOT="${CLAUDE_PROJECT_DIR:-$(harness_project_root "$SCRIPT_DIR")}"
 
 use_v1=0
 if source "$ROOT/../common/.harness/lib/session-state.sh" 2>/dev/null \
   && [[ "${HARNESS_SESSION_STATE_PROVIDER_VERSION:-}" == 1 ]] \
   && declare -F harness_validate_feature_name harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove >/dev/null; then
   use_v1=1
 fi
 compat_legacy() { printf '%s\n' 'compat: session-provider=legacy'; }
 
+prc=0
 sid="$(python3 -c '
 import json, re, sys
 try:
     d = json.load(sys.stdin)
     ev, sid, reason = d["hook_event_name"], d["session_id"], d["reason"]
 except Exception:
-    sys.exit(1)
+    sys.exit(3)
 if (ev != "SessionEnd" or not isinstance(sid, str)
         or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", sid)
         or reason not in ("clear", "resume", "logout", "prompt_input_exit", "other")):
-    sys.exit(1)
+    sys.exit(3)
 print(sid)
-')" || sid=""
+')" || prc=$?
 
-if [[ -z "$sid" ]]; then
+if [[ $prc == 3 ]]; then
   compat_legacy
   exit 0
 fi
+[[ $prc == 0 ]] || use_v1=0
 
 if [[ $use_v1 == 1 ]]; then
   project_id="$(realpath -- "$ROOT" | sha256sum)"
   project_id="${project_id%% *}"
   rc=0
   harness_session_state_remove "$project_id" "$sid" >/dev/null 2>&1 || rc=$?
   [[ $rc == 0 ]] || compat_legacy
 else
   compat_legacy
   rm -f -- "${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot" 2>/dev/null || true
```
