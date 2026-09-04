# review 包 b73676ba..b2fab190

## commit 列表

```
b2fab19 fix(claude): treat unverifiable SessionEnd input as zero-deletion
```

## diff --stat

```
 claude-code/features/.harness/hooks/session-end.sh | 4 ++--
 1 file changed, 2 insertions(+), 2 deletions(-)
```

## diff

```diff
diff --git a/claude-code/features/.harness/hooks/session-end.sh b/claude-code/features/.harness/hooks/session-end.sh
index 786cd2b..eda66a2 100755
--- a/claude-code/features/.harness/hooks/session-end.sh
+++ b/claude-code/features/.harness/hooks/session-end.sh
@@ -22,25 +22,25 @@ try:
     ev, sid, reason = d["hook_event_name"], d["session_id"], d["reason"]
 except Exception:
     sys.exit(3)
 if (ev != "SessionEnd" or not isinstance(sid, str)
         or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", sid)
         or reason not in ("clear", "resume", "logout", "prompt_input_exit", "other")):
     sys.exit(3)
 print(sid)
 ')" || prc=$?
 
-if [[ $prc == 3 ]]; then
+if [[ $prc != 0 ]]; then
+  cat >/dev/null 2>&1 || true
   compat_legacy
   exit 0
 fi
-[[ $prc == 0 ]] || use_v1=0
 
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
