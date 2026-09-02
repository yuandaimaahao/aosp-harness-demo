# Task 2.4 atomic-ref fuse verification

- Strict range: `e577c24a26525a372bb2827b567440a2d186eb33..6953c19e73a5edc500fcc2f26a1ef94474b9a1cf`
- Immutable package: `review-e577c24a-6953c19e.md`
- Commit: `6953c19 fix(harness): prevent stale fd double close`
- Exact head under test: `6953c19e73a5edc500fcc2f26a1ef94474b9a1cf`
- Authority: task 2.4 brief, implementation report, and prior fresh independent review R3
- Overall: **PASS** — Standards **PASS**, Spec **PASS**
- Findings: **0 Blocker / 0 Important / 0 Minor**

## Standards — PASS

The strict fuse range is one commit whose parent is exactly `e577c24a26525a372bb2827b567440a2d186eb33`. It changes only the two task-owned files: runtime `1/1` and tests `2/0` (`3 additions / 1 deletion`). `git diff --check` is clean. The cumulative task range `c5b7bfcec2372d03bcbb0be6f9b963e9ac86c6a1..6953c19e73a5edc500fcc2f26a1ef94474b9a1cf` remains runtime `56/4` plus tests `19/1`, exactly **75 additions**, satisfying the task ceiling (`75 <= 75`). No hard violation of `common/AGENTS.md` or `common/.harness/common.md`, scope creep, or new review-worthy Fowler smell was found.

## Spec — PASS

R3 I1 is closed. On successful stale-candidate inspection, the runtime now pops the candidate fd from `objects` before `_close`; the final `_drop(objects + nodes + ...)` therefore cannot close that integer again after the kernel reuses it. If `os.fstat(p)` fails, the pop is not reached, ownership remains in `objects`, and final cleanup still closes the candidate. Stale unlink eligibility and lock-held placement are otherwise unchanged.

Fresh deterministic instrumentation forced `/dev/null` to reuse the stale candidate's exact fd number. The predecessor provided the required negative control: it invoked `_close` again on the reused number and left the unrelated descriptor dead. Exact head invoked no later `_close` on that number, returned semantic exit 20, left the unrelated descriptor live, removed the eligible stale temp, left zero controlled temps, and returned to fd delta 0 after the probe explicitly closed its descriptor:

```text
e577c24a negative control
stale_fd=17 replacement_fd=17
close_after_reuse=1 replacement_alive=False

6953c19e exact head
stale_fd=17 replacement_fd=17
close_after_reuse=0 replacement_alive=True
stale_removed=True controlled_temps=0 fd_delta=0
```

The checked-in `ref-publish` regression independently asserts the same exact-number reuse, replacement liveness, stale-temp removal, zero controlled temps, explicit replacement close, and zero process-fd delta. Review of the strict patch found no change to object-first/ref-second commit ordering, adjacent locking, fault translation, replay, collision priority, evidence closure, or result bytes.

## Executable evidence

All target dynamic checks ran from a clean `git archive` of exact head at `/tmp/aosp-00a-2.4-fuse.bEy8A4`; the negative control ran from a separate archive of `e577c24a`. No real AOSP path was inspected, and no envsetup, lunch, build, sync, fetch/clone, package, flash, or download operation ran.

```text
PYTHONDONTWRITEBYTECODE=1 python3 common/tests/test_seed_contract_runtime.py canonical-core concurrent-core evidence-schema seed-schema terminal-golden state-paths store-object ref-resolve ref-publish
PASS canonical-core
PASS concurrent-core
PASS evidence-schema
PASS seed-schema
PASS terminal-golden
PASS state-paths
PASS store-object
PASS ref-resolve
PASS ref-publish

PYTHONDONTWRITEBYTECODE=1 bash common/tests/test-harness.sh
RESULT PASS  shared Harness regression suite

PYTHONDONTWRITEBYTECODE=1 bash common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约

PYTHONDONTWRITEBYTECODE=1 bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
RESULT PASS

git diff --check e577c24a26525a372bb2827b567440a2d186eb33..6953c19e73a5edc500fcc2f26a1ef94474b9a1cf
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **PASS**, 0 Blocker / 0 Important / 0 Minor.
- R3 I1: **closed**.
- Direct regressions and cumulative 75-line gate: **PASS**.
- Worst Standards issue: none.
- Worst Spec issue: none.
