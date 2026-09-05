#!/usr/bin/env bash
set -u
root=$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)
adapter=$root/common/.harness/bin/run-command.sh
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
fail() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}
run() {
  local want=$1
  shift
  "$@" >"$tmp/out" 2>"$tmp/err"
  local rc=$?
  [[ $rc == "$want" ]] || fail "rc=$rc want=$want"
}

run 2 env -u HARNESS_SESSION_ID bash "$adapter" query none -- true
[[ ! -s $tmp/out ]] || fail invalid-output
run 0 env HARNESS_SESSION_ID=test bash "$adapter" query none -- bash -c 'printf ok'
cmp -s "$tmp/out" <(printf ok) || fail query-output
grep -q '^runtime: class=query ' "$tmp/err" || fail query-diagnostic

mkdir -m 700 "$tmp/lease"
run 0 env HARNESS_SESSION_ID=test HARNESS_RESOURCE_LEASE_ROOT="$tmp/lease" bash "$adapter" build workspace-build -- true
find "$tmp/lease" -name 'active-*' -print -quit | grep -q . && fail workspace-release
run 0 env HARNESS_SESSION_ID=test ANDROID_INSTANCE_ID=cf-1 HARNESS_RESOURCE_LEASE_ROOT="$tmp/lease" bash "$adapter" mutate android-device -- true
run 0 env HARNESS_SESSION_ID=test ANDROID_INSTANCE_ID=cf-1 HARNESS_RESOURCE_LEASE_ROOT="$tmp/lease" bash "$adapter" cvd android-cvd -- true
run 2 env HARNESS_SESSION_ID=test ANDROID_INSTANCE_ID=bad/value bash "$adapter" query android-device -- true
run 2 env HARNESS_SESSION_ID=test HARNESS_COMMAND_BUILD_TIMEOUT_SECONDS=0 bash "$adapter" build none -- true
for skill in "$root"/claude-code/features/.harness/skills/build-{services-jar,sepolicy}/SKILL.md "$root"/codex/.agents/skills/build-{services-jar,sepolicy}/SKILL.md; do
  grep -Fq 'run-command.sh' "$skill" || fail "missing adapter guidance: $skill"
done
rm -rf -- "$tmp" || fail cleanup
trap - EXIT
printf 'RESULT PASS  command adapter\n'
