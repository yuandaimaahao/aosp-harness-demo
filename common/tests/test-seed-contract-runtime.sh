#!/usr/bin/env bash
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
fail(){ printf '%s\n' "$1" >&2; exit 1; }
case_name=all
if [[ $# -gt 0 ]]; then [[ $# -ge 2 && $1 == --case ]] || fail 'RESULT FAIL seed-contract-runtime'; case_name=$2; shift 2; fi
if [[ $case_name == rollback ]]; then
  [[ $# == 2 && $1 == --ledger && -f $2 ]] || fail 'ROLLBACK ERROR active delivery candidate unavailable'
  candidate=$(cd "$root" && python3 common/tests/test_seed_contract_runtime.py ledger-candidate --ledger "$2" 2>&1) || fail 'ROLLBACK ERROR active delivery candidate unavailable'
  [[ $candidate == 'PASS ledger-candidate active '* || $candidate == 'PASS ledger-candidate accepted '* ]] || fail 'ROLLBACK ERROR active delivery candidate unavailable'
  sha=${candidate##* }; parents=$(git -C "$root" rev-list --parents -n 1 "$sha" 2>/dev/null) || fail 'RESULT FAIL seed-contract-runtime'; [[ $(wc -w <<<"$parents") == 3 ]] || fail 'RESULT FAIL seed-contract-runtime'
  tmp=$(mktemp -d); cleanup(){ git -C "$root" worktree remove --force "$tmp" >/dev/null 2>&1 || { git -C "$root" worktree list --porcelain | grep -Fqx "worktree $tmp" || rm -rf -- "$tmp"; }; [[ ! -e $tmp ]] && ! git -C "$root" worktree list --porcelain | grep -Fqx "worktree $tmp"; }
  trap 'cleanup || exit 1' EXIT
  git -C "$root" worktree add --detach "$tmp" "$sha" >/dev/null 2>&1 || fail 'RESULT FAIL seed-contract-runtime'
  fixture=$tmp/common/.harness/closure/v1/commands.d/recovery-fixture; cp "$tmp/common/.harness/closure/v1/commands.d/verify-seed" "$fixture" && chmod 0755 "$fixture" && git -C "$tmp" add -- "$fixture" && git -C "$tmp" -c user.name=rollback -c user.email=rollback@invalid commit -m 'test: add recovery fixture' >/dev/null 2>&1 && git -C "$tmp" -c user.name=rollback -c user.email=rollback@invalid revert -m 1 --no-edit "$sha" >/dev/null 2>&1 || fail 'RESULT FAIL seed-contract-runtime'
  gone(){ [[ ! -e $1 && ! -L $1 ]]; }; set +e; "$fixture" >"$tmp/out" 2>"$tmp/err"; rc=$?; set -e
  [[ $rc == 30 && ! -s $tmp/out && -f $fixture && ! -L $fixture && -x $fixture ]] && cmp -s "$tmp/err" <(printf 'CONTRACT RUNTIME_UNAVAILABLE\n') && gone "$tmp/common/.harness/bin/feature-closure" && gone "$tmp/common/.harness/closure/v1/runtime/seed-contract-runtime.version" && gone "$tmp/common/.harness/closure/v1/lib/seed_contract_runtime.py" && gone "$tmp/common/.harness/closure/v1/commands.d/verify-seed" || fail 'RESULT FAIL seed-contract-runtime'
  (cd "$tmp" && bash common/tests/test-harness.sh >"$tmp/hout" 2>"$tmp/herr") && (cd "$tmp" && bash common/.harness/bin/check-parity.sh >"$tmp/pout" 2>"$tmp/perr") && (cd "$tmp" && bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo >"$tmp/sout" 2>"$tmp/serr") || fail 'RESULT FAIL seed-contract-runtime'
  [[ ! -s $tmp/herr && ! -s $tmp/perr && ! -s $tmp/serr ]] && tail -n1 "$tmp/hout" | cmp -s - <(printf 'RESULT PASS  shared Harness regression suite\n') && cmp -s "$tmp/pout" <(printf 'PARITY PASS  Claude/Codex 共享同一公共契约\n') && tail -n1 "$tmp/sout" | cmp -s - <(printf 'RESULT PASS\n') || fail 'RESULT FAIL seed-contract-runtime'
  trap - EXIT; cleanup || fail 'RESULT FAIL seed-contract-runtime'; printf 'RESULT PASS seed-contract-runtime\n'; exit 0
fi
[[ $# == 0 ]] || fail 'RESULT FAIL seed-contract-runtime'
declare -A routes=([all]='canonical-core evidence-schema seed-schema terminal-golden state-paths store-object ref-resolve ref-publish cli' [cli]=cli [digest-immutability]='store-object ref-resolve ref-publish' [path-confinement]=state-paths [failure-ref-rules]=ref-publish [public-real-gate]=ref-resolve)
tests=${routes[$case_name]-}; [[ -n $tests ]] || fail 'RESULT FAIL seed-contract-runtime'
out=$(mktemp); err=$(mktemp); trap 'unlink "$out"; unlink "$err"' EXIT
(cd "$root" && python3 common/tests/test_seed_contract_runtime.py $tests >"$out" 2>"$err") && printf 'PASS %s\n' $tests | cmp -s - "$out" && [[ ! -s $err ]] || { cat "$out" "$err" >&2; exit 1; }
trap - EXIT; unlink "$out"; unlink "$err"
printf 'RESULT PASS seed-contract-runtime\n'
