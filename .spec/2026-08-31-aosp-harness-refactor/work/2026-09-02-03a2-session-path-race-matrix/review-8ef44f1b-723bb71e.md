# review 包 8ef44f1b..723bb71e

## commit 列表

```
723bb71 test(session): classify race dependencies
```

## diff --stat

```
 tests/test-session-path-races.sh | 37 ++++++++++++++++++++++++++++++++++++-
 1 file changed, 36 insertions(+), 1 deletion(-)
```

## diff

```diff
diff --git a/tests/test-session-path-races.sh b/tests/test-session-path-races.sh
index 24d81b7..1edac44 100755
--- a/tests/test-session-path-races.sh
+++ b/tests/test-session-path-races.sh
@@ -1,32 +1,37 @@
 #!/usr/bin/env bash
 set -u
 export LC_ALL=C

 SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
 ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
+FOUNDATION="$ROOT/common/.harness/lib/session-state-foundation.sh"
 PROVIDER="$ROOT/common/.harness/lib/session-state-path.sh"
+DRIVER="$ROOT/tests/lib/session-path-race-driver.py"
 TMP_TEST=$(mktemp -d "${TMPDIR:-/tmp}/session-path-races-03a2.XXXXXX")
 trap 'rm -rf -- "$TMP_TEST"' EXIT
 SUMMARY='RESULT PASS  session path race assurance'
+DRIVER_PROTOCOL='session-path-race-driver-v1'

 fail() {
   printf 'FAIL %s\n' "$1" >&2
   exit 1
 }

 case ${1:-all} in
   --dependency-absent)
     [[ $# == 1 ]] || fail 'option: dependency-absent takes no value'
+    GROUP=dependency-absent
     ;;
   all)
     (($# <= 1)) || fail 'option: all takes no value'
+    GROUP=all
     ;;
   *) fail "option: ${1:-empty} unsupported" ;;
 esac

 CASE_TSV="$TMP_TEST/cases.tsv"
 for layer in root project session; do
   for kind in safe-dir link file; do
     printf 'swap-%s-%s\tswap\t%s\t%s\n' "$layer" "$kind" "$layer" "$kind"
   done
 done >"$CASE_TSV"
@@ -80,16 +85,46 @@ done
 [[ ! -v HARNESS_SESSION_STATE_PROVIDER_VERSION ]]
 SH
 }

 pass_inert() {
   inert_surface || fail 'dependency absent: inert surface'
   printf '%s\n' "$SUMMARY"
   exit 0
 }

+core_available() {
+  FOUNDATION=$FOUNDATION PROVIDER=$PROVIDER bash <<'SH'
+set -u
+unset -f harness_validate_feature_name _harness_session_state_foundation_path _harness_session_state_run \
+  _harness_session_path_core 2>/dev/null || :
+[[ -f $FOUNDATION ]] || exit 1
+source "$FOUNDATION" || exit 1
+source "$PROVIDER" || exit 1
+declare -F _harness_session_path_core >/dev/null
+SH
+}
+
 validate_matrix || fail '37 unique rows and nine category counts'
 matrix_self_disproof
 if [[ ! -e $PROVIDER && ! -L $PROVIDER ]]; then
   pass_inert
 fi
-fail 'dependency classifier incomplete'
+for marker in HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN HARNESS_TEST_MARKER_EXPECTED_EUID HARNESS_TEST_MARKER_OS_ERROR; do
+  count=$(grep -Fo "$marker" "$PROVIDER" | wc -l)
+  [[ $count == 1 ]] || fail 'provider anchors: expected each exactly once'
+done
+if [[ -L $DRIVER || (-e $DRIVER && ! -f $DRIVER) ]]; then
+  fail 'race driver: expected regular non-symlink file'
+fi
+if [[ ! -e $DRIVER ]]; then
+  pass_inert
+fi
+printf '%s\n' "$DRIVER_PROTOCOL" >"$TMP_TEST/protocol.expected"
+if ! python3 "$DRIVER" protocol >"$TMP_TEST/protocol.out" 2>"$TMP_TEST/protocol.err"; then
+  fail 'race driver protocol execution'
+fi
+[[ ! -s $TMP_TEST/protocol.err ]] && cmp -s "$TMP_TEST/protocol.out" "$TMP_TEST/protocol.expected" || fail 'race driver protocol bytes'
+if [[ $GROUP == dependency-absent ]] || ! core_available; then
+  pass_inert
+fi
+fail 'race adapter incomplete'
```
