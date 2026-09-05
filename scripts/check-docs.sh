#!/usr/bin/env bash
set -u
root=$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P) || exit 1
fail() {
  printf 'DOCS FAIL  %s\n' "$1" >&2
  exit 1
}
for path in \
  common/.harness/bin/harness-resolve-contract \
  common/.harness/bin/harness-client-launch \
  common/.harness/bin/harness-verify \
  common/.harness/bin/run-command.sh \
  docs/verifier-contract.md \
  common/README.md; do
  [[ -e $root/$path ]] || fail "missing $path"
done
for executable in \
  common/.harness/bin/harness-resolve-contract \
  common/.harness/bin/harness-client-launch \
  common/.harness/bin/harness-verify \
  common/.harness/bin/run-command.sh; do
  [[ -x $root/$executable ]] || fail "not executable: $executable"
done
for phrase in \
  'bash scripts/check.sh --offline' \
  'harness-resolve-contract' \
  'harness-client-launch' \
  'harness-verify dev-sidebar --demo' \
  'ANDROID_INSTANCE_ID' \
  'contract_version=v2' \
  'RESULT PASS'; do
  grep -Fq "$phrase" "$root/README.md" || fail "README missing: $phrase"
done
grep -Fq 'docs/verifier-contract.md' "$root/README.md" || fail 'verifier contract link'
grep -Fq 'common/README.md' "$root/README.md" || fail 'common README link'
printf 'RESULT PASS  docs readiness\n'
