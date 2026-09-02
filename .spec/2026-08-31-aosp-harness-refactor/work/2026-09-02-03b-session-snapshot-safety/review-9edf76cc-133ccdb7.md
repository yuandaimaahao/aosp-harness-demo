# review 包 9edf76cc..133ccdb7

## commit 列表

```
133ccdb fix(session): suppress stderr on capture temp-file failure paths
```

## diff --stat

```
 common/.harness/lib/session-state-snapshot.sh | 8 ++++----
 1 file changed, 4 insertions(+), 4 deletions(-)
```

## diff

```diff
diff --git a/common/.harness/lib/session-state-snapshot.sh b/common/.harness/lib/session-state-snapshot.sh
index 7e3dffe..2f1ea42 100644
--- a/common/.harness/lib/session-state-snapshot.sh
+++ b/common/.harness/lib/session-state-snapshot.sh
@@ -182,26 +182,26 @@ except Interrupted: raise SystemExit(128 + first_signal[0])
 except Missing: raise SystemExit(3)
 except Unsafe: raise SystemExit(2)
 except (OSError, Failed, AttributeError): raise SystemExit(128 + first_signal[0] if first_signal[0] is not None else 1)
 PY
     }
     _harness_snapshot_dispatch() {
       [[ ($# == 3 && $1 == read) || ($# == 4 && $1 == write) ]] || return 2
       local op=$1 project=$2 session=$3 feature=${4-} path_file path_fd rc
       if [[ $op == write ]] && ! harness_validate_feature_name "$feature" >/dev/null 2>&1; then return 2; fi
       umask 077
-      path_file=$(mktemp "${TMPDIR:-/tmp}/snapshot-path.XXXXXXXX") || return 1
-      exec {path_fd}<>"$path_file" || {
-        rm -f -- "$path_file"
+      path_file=$(mktemp "${TMPDIR:-/tmp}/snapshot-path.XXXXXXXX" 2>/dev/null) || return 1
+      exec {path_fd}<>"$path_file" 2>/dev/null || {
+        rm -f -- "$path_file" 2>/dev/null
         return 1
       }
-      rm -f -- "$path_file" || return 1
+      rm -f -- "$path_file" 2>/dev/null || return 1
       : # HARNESS_TEST_MARKER_CAPTURE_READY
       _harness_session_path_core "$project" "$session" 2>/dev/null 1>&"$path_fd"
       rc=$?
       ((rc == 0)) || return "$rc"
       _harness_snapshot_exec "$op" "$path_fd" "$project" "$session" "$feature"
     }
     _harness_snapshot_dispatch "$@"
   }
   _harness_session_snapshot_write_core() (_harness_session_snapshot_worker write "$@")
   _harness_session_snapshot_read_core() (_harness_session_snapshot_worker read "$@")
```
