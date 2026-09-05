#!/usr/bin/env bash
set -u
root=$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)
verify=$root/common/.harness/bin/harness-verify
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
fail() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}

"$verify" dev-sidebar --demo >"$tmp/out" 2>"$tmp/err" || fail demo
grep -Fxq 'RESULT PASS' "$tmp/out" || fail demo-result
grep -Fxq 'contract_version=v2' "$tmp/err" || fail demo-version
"$verify" unknown --demo >"$tmp/out" 2>"$tmp/err" && fail unknown
ANDROID_SERIAL=demo "$verify" dev-sidebar >"$tmp/out" 2>"$tmp/err" && fail missing-control

mkdir -p "$tmp/bin"
cat >"$tmp/bin/adb" <<'SH'
#!/usr/bin/env bash
shift 2
case "$*" in
  'shell getprop sys.boot_completed') printf '1\n' ;;
  'shell pidof system_server') printf '1\n' ;;
  'shell cat /proc/stat') printf 'btime 100\n' ;;
  logcat*) : ;;
  'shell service list') printf '1 sidebar: [x]\n' ;;
  'shell pm list packages') printf 'package:com.android.sidebar\n' ;;
  *) exit 9 ;;
esac
SH
chmod +x "$tmp/bin/adb"
PATH="$tmp/bin:$PATH" ANDROID_SERIAL=demo HARNESS_RESOURCE_LEASE_ROOT="$tmp/leases" "$verify" dev-sidebar --session-id verify-test --android-instance-id cf-1 >"$tmp/out" 2>"$tmp/err" || fail real
grep -Fxq 'RESULT PASS' "$tmp/out" || fail real-result
[[ $(grep -c '^runtime: class=query ' "$tmp/err") == 6 ]] || fail runtime-count
find "$tmp/leases" -name 'active-*' -print -quit | grep -q . && fail release
rm -rf -- "$tmp" || fail cleanup
trap - EXIT
printf 'RESULT PASS  verifier adapters\n'
