# review 包 133ccdb7..192fa1e1

## commit 列表

```
192fa1e fix(session): scope capture fd-open stderr suppression to the exec itself
```

## diff --stat

```
 common/.harness/lib/session-state-snapshot.sh | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

## diff

```diff
diff --git a/common/.harness/lib/session-state-snapshot.sh b/common/.harness/lib/session-state-snapshot.sh
index 2f1ea42..954a0b2 100644
--- a/common/.harness/lib/session-state-snapshot.sh
+++ b/common/.harness/lib/session-state-snapshot.sh
@@ -183,21 +183,21 @@ except Missing: raise SystemExit(3)
 except Unsafe: raise SystemExit(2)
 except (OSError, Failed, AttributeError): raise SystemExit(128 + first_signal[0] if first_signal[0] is not None else 1)
 PY
     }
     _harness_snapshot_dispatch() {
       [[ ($# == 3 && $1 == read) || ($# == 4 && $1 == write) ]] || return 2
       local op=$1 project=$2 session=$3 feature=${4-} path_file path_fd rc
       if [[ $op == write ]] && ! harness_validate_feature_name "$feature" >/dev/null 2>&1; then return 2; fi
       umask 077
       path_file=$(mktemp "${TMPDIR:-/tmp}/snapshot-path.XXXXXXXX" 2>/dev/null) || return 1
-      exec {path_fd}<>"$path_file" 2>/dev/null || {
+      { exec {path_fd}<>"$path_file"; } 2>/dev/null || {
         rm -f -- "$path_file" 2>/dev/null
         return 1
       }
       rm -f -- "$path_file" 2>/dev/null || return 1
       : # HARNESS_TEST_MARKER_CAPTURE_READY
       _harness_session_path_core "$project" "$session" 2>/dev/null 1>&"$path_fd"
       rc=$?
       ((rc == 0)) || return "$rc"
       _harness_snapshot_exec "$op" "$path_fd" "$project" "$session" "$feature"
     }
```
