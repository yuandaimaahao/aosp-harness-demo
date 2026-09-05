#!/usr/bin/env bash
set -u
root=$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)
resolver=$root/common/.harness/bin/harness-resolve-contract
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
fail() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}
for client in claude codex; do
  "$resolver" --client "$client" --root "$root" >"$tmp/$client" 2>"$tmp/$client.err" || fail "$client resolve"
  [[ ! -s $tmp/$client.err ]] || fail "$client stderr"
  LC_ALL=C sort -c "$tmp/$client" || fail "$client sort"
  grep -Fxq 'contract_version=v2' "$tmp/$client" || fail "$client version"
  grep -Fxq "name=$client" "$tmp/$client" || fail "$client name"
  grep -Eq '^contract_sha256=[0-9a-f]{64}$' "$tmp/$client" || fail "$client hash"
done
"$resolver" --client unknown --root "$root" >"$tmp/out" 2>"$tmp/err" && fail unknown
cp -a "$root/common" "$tmp/common"
printf 'name=claude\nname=again\n' >"$tmp/common/.harness/clients/claude/client.conf"
HARNESS_ROOT="$root/common" "$tmp/common/.harness/bin/harness-resolve-contract" --client claude --root "$root/common" >"$tmp/out" 2>"$tmp/err" && fail duplicate
rm -rf -- "$tmp" || fail cleanup
trap - EXIT
printf 'RESULT PASS  registry resolver\n'
