# Task 2.1 R3 M1 fuse verification

- Range: `a01b436dac32422ec849d471197a6b6d6e621093..657785d355015fbb22390802167533ef542782d8`
- Immutable package: `review-a01b436d-657785d3.md`
- Overall: **PASS**
- Findings: **0 Blocker / 0 Important / 0 Minor**

## Findings

None.

## Standards — PASS

The exact fix range is one commit whose parent is exactly `a01b436dac32422ec849d471197a6b6d6e621093`; it changes only `common/tests/test_seed_contract_runtime.py` (`4/4`). `git diff --check` is clean. The test-only correction introduces no hard violation of the applicable `common/AGENTS.md` guidance and no review-worthy Fowler smell beyond the repository's established compact test style.

The cumulative task range `b0d0b133da3a161aa2fde448033f7b737f8881be..657785d355015fbb22390802167533ef542782d8` remains limited to the two task-owned files and is runtime `49/1` plus test `16/1`: exactly **65 additions**, satisfying the task ceiling.

## Spec — PASS

R3 M1 is closed by checked-in assertions, not only by report prose:

- Exact-head test line 99 defines a recursive relative-entry snapshot for the complete temporary fixture root.
- Exact-head line 109 takes a snapshot immediately before every stable failure in `bads`, checks the exact `ContractError` code, then asserts exact snapshot equality.
- The covered table includes the static state-dir symlink, equal/ancestor forbidden-root containment, missing forbidden leaf, out-ref escape, static ref-parent symlink, and static store-parent symlink cases. Because both symlink targets and all containment/escape fixtures are beneath the snapshotted root, any surviving entry created through or outside the intended state path changes the snapshot and fails the test.
- The prior standalone store-symlink assertion and ref-symlink assertion were moved into that same table without weakening their expected codes. No runtime code changed.

The same-effective-UID active rename boundary remains honest and distinct. Exact-head line 107 is unchanged by this fix: both deterministic post-`mkdirat` schedules still require fail-closed `STATE_DIR_CONTRACT` / `OUT_REF_CONTRACT`, record an attempted lexical `rmdir` as best-effort cleanup, and explicitly require the adversarially moved directory to remain visible. These cases execute before the stable-failure snapshot loop, so the newly added equality assertion does not falsely claim zero residuals for the excluded threat.

No test weakening or direct regression was found.

## Executable evidence

All dynamic commands ran in a `git archive` of exact head `657785d355015fbb22390802167533ef542782d8`. No AOSP source was read and no AOSP envsetup, lunch, build, sync, fetch, clone, package, flash, or download command ran.

```text
timeout 20s python3 common/tests/test_seed_contract_runtime.py state-paths
PASS state-paths

python3 common/tests/test_seed_contract_runtime.py canonical-core concurrent-core evidence-schema seed-schema terminal-golden state-paths
PASS canonical-core
PASS concurrent-core
PASS evidence-schema
PASS seed-schema
PASS terminal-golden
PASS state-paths

bash common/tests/test-harness.sh
RESULT PASS  shared Harness regression suite

bash common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约

bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
RESULT PASS

git diff --check a01b436dac32422ec849d471197a6b6d6e621093..657785d355015fbb22390802167533ef542782d8
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **PASS**, 0 Blocker / 0 Important / 0 Minor.
- R3 M1: **closed**.
- Direct regression: **PASS**.
