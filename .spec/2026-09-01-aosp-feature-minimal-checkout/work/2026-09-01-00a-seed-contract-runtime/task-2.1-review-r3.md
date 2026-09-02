# Task 2.1 fresh independent security review R3

- Range: `b0d0b133da3a161aa2fde448033f7b737f8881be..a01b436dac32422ec849d471197a6b6d6e621093`
- Immutable package: `review-b0d0b133-a01b436d.md`
- Prior reviews: `task-2.1-review-r1.md`, `task-2.1-review-r2.md`
- Superseding authority: latest `DECISIONS.md` row and updated task brief R5/R6 filesystem threat boundary
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**
- Findings: **0 Blocker / 0 Important / 1 Minor**

## Standards — PASS

The exact cumulative range changes only the two task-owned files. `git diff --numstat` is runtime `49/1` and test `16/1`: exactly 65 additions, within the task ceiling (`65 <= 65`). `git diff --check` is clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found, and no review-worthy Fowler smell is introduced beyond the repository's established compact runtime/test style.

## Spec — FAIL

### M1 — the task suite does not assert the stable-topology zero-outside-entry invariant

The updated brief's task step 1 explicitly requires stable-topology failures to verify zero outside entries, and the superseding threat boundary expressly preserves that guarantee for static symlink/no-follow/containment failures. Exact-head test line 105 invokes `bad(...)` for a store-parent symlink targeting `root`, but never snapshots or inspects that target afterward; the forbidden-root/escape cases at line 104 likewise check only the error code. An implementation that created an entry through the static symlink or beyond a forbidden boundary and then failed with the expected `ContractError` could therefore leave `PASS state-paths` green.

This is a test-coverage finding, not a current runtime escape: independent exact-head probes snapshotting static store/ref symlink targets and checking rollback after an invalid ref found zero outside entries and no residual created artifact parents. Add explicit before/after directory snapshots or sentinels for static symlink and containment failure cases.

## Superseded R2 blocker disposition

R2 B1 is not an in-scope blocker under the explicit September 2 adjudication. Same-effective-UID active rename/move/delete during an invocation is excluded; detected changes require only fail-closed behavior and best-effort cleanup, not recovery of an inode moved to an unknown name.

The new exact-head schedules are honest. Test line 107 waits until `source.exists()` after `_walk`'s `mkdirat`, moves newly created `v1` or `refs` immediately before the monkeypatched `os.open`, then asserts the exact contract code and observes an attempted `rmdir` of the lexical name. It deliberately permits the moved directory to remain. Independent schedules reproduced `STATE_DIR_CONTRACT` for the object path and `OUT_REF_CONTRACT` for the ref path, recorded the cleanup attempts, and confirmed the moved residuals, exactly matching the approved boundary.

## Confirmed implementation behavior

- `validate_state_paths` has the four exact keyword-only parameters; positional, missing-keyword, and unknown-keyword shapes raise native `TypeError`. Bound container/value type errors tested return `ARGUMENT_ERROR` before state/ref validation.
- Successful results are immutable `mappingproxy` values with exactly six required keys and normalized absolute derivations; absent `out_ref` yields three null ref fields.
- Static state/store/ref-component symlinks, existing ref symlink/FIFO/socket/directory leaves, wrong store, escape, equal/descendant forbidden roots, and missing lexical leaves under a forbidden root fail with the required staged code. FIFO classification is bounded and nonblocking.
- Prefix siblings are accepted. A mode `0300` writable/searchable state succeeds; mode `0200` fails. A 200-call success loop left `/proc/self/fd` count unchanged.
- Independent stable-topology snapshots found zero entries written through static symlink targets and successful cleanup of in-state parents on ref-contract failure.
- The red evidence records the required missing-API failure. The exact range contains no AOSP access, envsetup, lunch, build, sync, fetch, clone, package, flash, or download operation.

## Executable evidence

All dynamic checks ran from an archive-isolated exact-head tree at `/tmp/aosp-harness-2.1-r3.rN4bA3/tree`, commit `a01b436dac32422ec849d471197a6b6d6e621093`. No real AOSP path was inspected.

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

independent R5/R6/R12/API/priority/permissions/fd/static-zero/rename-boundary probe
PASS independent-r5-r6-r12-api-priority-permissions-fd-static-zero-rename-boundary

bash common/tests/test-harness.sh
RESULT PASS  shared Harness regression suite

bash common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约

bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
final: RESULT PASS

git diff --check b0d0b133da3a161aa2fde448033f7b737f8881be..a01b436dac32422ec849d471197a6b6d6e621093
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 0 Blocker / 0 Important / 1 Minor.
- Worst Standards issue: none.
- Worst Spec issue: the checked-in task case omits an explicit assertion for the preserved stable-topology zero-outside-entry invariant.
