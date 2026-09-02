# Task 2.1 fresh independent security review R2

- Range: `b0d0b133da3a161aa2fde448033f7b737f8881be..349fb437895d3da09f1d65a4d42ae46eb35e3070`
- Immutable package: `review-b0d0b133-349fb437.md`
- Prior review: `task-2.1-review-r1.md`
- Commits: `3c3efcb feat(harness): confine runtime state paths`; `79fec29 fix(harness): harden state path validation`; `349fb43 fix(harness): fail closed on state races`
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**
- Findings: **1 Blocker / 0 Important / 1 Minor**

## Standards — PASS

The exact cumulative range changes only the two task-owned files. `git diff --numstat` is runtime `49/1` and test `16/1`: exactly 65 additions, within the task ceiling (`65 <= 65`). `git diff --check` is clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found, and no review-worthy Fowler smell is introduced beyond the established compact runtime/test style.

## Spec — FAIL

### B1 — a creation-time rename defeats rollback and leaves a runtime-created directory outside state

Runtime lines 43–46 perform `mkdirat`, remember only `(parent_fd, lexical_name)`, and then reopen the new component. On failure, `_clean` at lines 32–35 can remove only that original name and silently ignores cleanup errors. If a concurrent rename moves the just-created component after `mkdirat` returns but before the reopen, the reopen fails and rollback looks for a name that no longer exists; the moved, runtime-created directory persists outside `state_dir`.

Two exact-head scheduled thread probes reproduced this deterministically. Moving newly created `artifacts/v1` produced `STATE_DIR_CONTRACT` while leaving `outside/leaked-v1`. With the object tree pre-created, moving newly created `refs` produced `OUT_REF_CONTRACT` while leaving `outside/leaked-refs`. Both directories were created by this invocation and remained after it returned. This violates R5/R6 confinement, R12's zero-change rule for path-contract failures, and the explicit invariant that path/symlink/containment failures create zero filesystem entries outside state. Retaining and rechecking ancestor fds closes the prior existing-parent race only when rollback can still address every created child; the creation/cleanup operation itself remains check/use vulnerable.

### M1 — the regression race stops before exercising the vulnerable creation/cleanup window

Test line 107 moves the pre-existing `artifacts` directory from inside a monkeypatched `_same` call and asserts that `moved/v1` was never created. That covers the prior review's exact schedule, but it does not schedule a rename after `mkdirat` creates a component or assert rollback when a created component's lexical name disappears. Therefore `PASS state-paths` remains green while B1 leaves an outside entry. A bounded subprocess timeout around the FIFO case would also make the former hang regression fail deterministically rather than relying on a suite-level timeout.

## R1 finding disposition

- **B1 closed:** existing FIFO/socket/directory/symlink ref leaves are classified with no-follow metadata rather than blocking reads. The independent FIFO call returned `OUT_REF_CONTRACT` in under 0.5 seconds.
- **B2 partially closed:** moving an already-open existing parent between identity validation and `mkdirat` now fails `STATE_DIR_CONTRACT`, and the independently scheduled benign case removed the redirected child from the moved parent. B1 above shows the adjacent post-`mkdirat` schedule still escapes cleanup.
- **I1 closed:** malformed, non-string, relative, non-normalized, symlink-spelled, and NUL-containing `forbidden_roots` elements return `ARGUMENT_ERROR` before deliberately invalid state/store values are examined.
- **M1 closed:** directory traversal uses `O_PATH|O_DIRECTORY|O_NOFOLLOW`; a mode `0300` writable/searchable state succeeds, while a mode `0200` non-searchable state fails `STATE_DIR_CONTRACT`.
- **M2 partially closed:** the task case now covers the original FIFO, non-regular leaf, invalid-root priority, search-only permission, prefix sibling, store symlink, and one scheduled rename, but misses B1's creation-time schedule.

## Confirmed contract coverage

- The API is keyword-only; positional, missing-keyword, and unknown-keyword shapes raise native `TypeError`. Successfully bound invalid value/container types raise `ARGUMENT_ERROR`.
- The successful result is an immutable `mappingproxy` with exact ordered keys `{state_dir,artifact_store,object_dir,out_ref,ref_parent,lock_path}`, exact normalized absolute derivations, and three null ref fields when `out_ref` is absent.
- Independent R5/R6 probes covered relative/tilde/missing/non-directory/unwritable/non-searchable state, wrong store, state/store/ref symlinks, regular/FIFO/socket/directory ref leaves, lexical escape, equal/ancestor/root/store forbidden containment, missing forbidden leaf, and prefix-sibling acceptance. Static failures removed created parents and did not change an outside sentinel.
- A 200-iteration success/`OUT_REF_CONTRACT`/`ARGUMENT_ERROR` loop left `/proc/self/fd` count unchanged. No other new fd leak or blocking path was found.
- The red asset records the required missing-API failure. The strict range contains no AOSP access, envsetup, lunch, build, sync, fetch, clone, package, flash, or download operation.

## Executable evidence

All dynamic checks ran in detached exact-head worktree `/tmp/aosp-harness-2.1-r2.ENaSDm/tree` at `349fb437895d3da09f1d65a4d42ae46eb35e3070`. No real AOSP path was inspected.

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

independent full R5/R6/API/priority/timeout/cleanup/fd probe
race existing parent after check: STATE_DIR_CONTRACT; moved parent entries=[]
race newly-created object component: STATE_DIR_CONTRACT; outside entries=['leaked-v1']
race newly-created ref component: OUT_REF_CONTRACT; outside entries=['leaked-refs']
PASS independent-full-r5-r6-priority-api-timeout-cleanup-fd

bash common/tests/test-harness.sh
RESULT PASS  shared Harness regression suite

bash common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约

bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
final: RESULT PASS

git diff --check b0d0b133da3a161aa2fde448033f7b737f8881be..349fb437895d3da09f1d65a4d42ae46eb35e3070
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 1 Blocker / 0 Important / 1 Minor.
- Worst Standards issue: none.
- Worst Spec issue: creation-time rename can leave a runtime-created directory outside state after a contract failure.
