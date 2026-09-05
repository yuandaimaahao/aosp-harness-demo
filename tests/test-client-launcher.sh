#!/usr/bin/env bash
set -u
root=$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)
launcher=$root/common/.harness/bin/harness-client-launch
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
fail() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}

HARNESS_STATE_ROOT="$tmp/state" HARNESS_SESSION_ID=test-session "$launcher" claude --dry-run -- >"$tmp/out" 2>"$tmp/err" || fail dry-run
grep -Fxq 'contract_version=v2' "$tmp/out" || fail contract
grep -Fxq 'contract_version=v2' "$tmp/err" || fail capability
grep -Fxq 'command=claude' "$tmp/out" || fail command

HARNESS_SESSION_ID=bad/value "$launcher" claude --dry-run -- >"$tmp/out" 2>"$tmp/err" && fail invalid-session
mkdir -p "$tmp/bin"
cat >"$tmp/bin/codex" <<'SH'
#!/usr/bin/env bash
printf 'client:%s\n' "$*"
SH
chmod +x "$tmp/bin/codex"
PATH="$tmp/bin:$PATH" HARNESS_ROOT="$root" HARNESS_STATE_ROOT="$tmp/state" HARNESS_SESSION_ID=launch-test HARNESS_RESOURCE_LEASE_ROOT="$tmp/leases" "$launcher" codex -- --flag >"$tmp/out" 2>"$tmp/err" || fail launch
grep -Fxq 'client:--flag' "$tmp/out" || fail argv
grep -Fq 'runtime: class=query' "$tmp/err" || fail runtime
find "$tmp/leases" -name 'active-*' -print -quit | grep -q . && fail release
rm -rf -- "$tmp" || fail cleanup
trap - EXIT
printf 'RESULT PASS  client launcher\n'
