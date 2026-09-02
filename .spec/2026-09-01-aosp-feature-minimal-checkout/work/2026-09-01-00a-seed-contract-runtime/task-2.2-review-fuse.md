# Task 2.2 R3 fuse verification

- Range: `d65d12075f6d6cf7fcf45e3c924bcabc52a74eff..770fc1ff68bb01f1dd90e6ad6ec27ffd58e6737a`
- Immutable package: `review-d65d1207-770fc1ff.md`
- Exact head: `770fc1ff68bb01f1dd90e6ad6ec27ffd58e6737a`
- Overall: **PASS**
- Findings: **0 Blocker / 0 Important / 0 Minor**

## Findings

None.

## Standards — PASS

The exact fix range is one commit whose parent is exactly `d65d12075f6d6cf7fcf45e3c924bcabc52a74eff`. It changes only the two task-owned files (`14` insertions / `5` deletions), and `git diff --check` is clean. The package and strict range contain the same added and removed lines.

The cumulative task range `657785d355015fbb22390802167533ef542782d8..770fc1ff68bb01f1dd90e6ad6ec27ffd58e6737a` remains limited to those two files: runtime `42/1` plus test `36/1`, exactly **78 additions**, satisfying the `<=80` task ceiling. No hard violation of `common/AGENTS.md` or `common/.harness/common.md`, and no new review-worthy Fowler smell, was found.

## Spec — PASS

R3 I1 is closed. Exact-head runtime lines 210–214 place the EEXIST loser recheck (`read(digest)` plus object-directory `fsync`) inside a nested `try` whose `OSError` path reaches the deterministic final translation. Since `linked` remains false when `linkat` reports EEXIST, classify, read-open, matching-object file-fsync, and directory-fsync failures all become `PUBLISH_PRECOMMIT_FAILED`. The inner handler catches only `OSError`, so `read()` mismatch `ContractError("DIGEST_COLLISION")` still propagates unchanged. Function and nested `finally` blocks close the anonymous inode, object-directory fd, walk fds, probe fd, and read fd on every exercised path.

R3 M1 is closed by checked-in exact assertions:

- Test lines 116–120 observe `O_TMPFILE`, exact regular-file fsync modes in order `0600` then `0444`, followed by directory fsync, and exact link attempts/results `[(0x1000,-1),(0x400,0)]`.
- Line 126 checks that a differing digest leaf returns `DIGEST_COLLISION` while preserving its exact bytes and 0444 mode.
- Lines 127–133 inject all four EEXIST-loser failures, require `PUBLISH_PRECOMMIT_FAILED`, require zero fd-count delta, and preserve the peer-created canonical 0444 object.

An independent exact-head probe reproduced all four translations with fd delta 0. A separate EEXIST-loser mismatch probe returned `DIGEST_COLLISION` with fd delta 0 and preserved adversarial bytes and 0444 mode. The normal probe observed fsync targets/modes `regular 0600`, `regular 0444`, `directory`, link flags/results `(0x1000,-1)`, `(0x400,0)`, and a final immutable 0444 object.

The runtime fix only wraps race recheck durability operations for translation; it does not alter anonymous `O_TMPFILE`, complete-write, chmod, fsync, hard-link no-replace, collision arbitration, or object-directory commit order. No direct regression was found.

## Executable evidence

All dynamic commands ran in a `git archive` of exact head at `/tmp/aosp-00a-2.2-fuse.5j9OJl`. No real AOSP path was inspected, and no AOSP envsetup, lunch, build, sync, fetch/clone, package, flash, or download command ran.

```text
PYTHONDONTWRITEBYTECODE=1 timeout 60s python3 common/tests/test_seed_contract_runtime.py canonical-core concurrent-core evidence-schema seed-schema terminal-golden state-paths store-object
PASS canonical-core
PASS concurrent-core
PASS evidence-schema
PASS seed-schema
PASS terminal-golden
PASS state-paths
PASS store-object

bash common/tests/test-harness.sh
RESULT PASS  shared Harness regression suite

bash common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约

bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
RESULT PASS

independent exact-head probes
commit fsync_modes=0600,0444,dir link_flags_results=(0x1000,-1),(0x400,0) final_mode=0444
eexist_classify PUBLISH_PRECOMMIT_FAILED fd_delta=0
eexist_read PUBLISH_PRECOMMIT_FAILED fd_delta=0
eexist_file_fsync PUBLISH_PRECOMMIT_FAILED fd_delta=0
eexist_dir_fsync PUBLISH_PRECOMMIT_FAILED fd_delta=0
eexist_mismatch DIGEST_COLLISION fd_delta=0 bytes_preserved=true mode=0444

git diff --check 657785d355015fbb22390802167533ef542782d8..770fc1ff68bb01f1dd90e6ad6ec27ffd58e6737a
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **PASS**, 0 Blocker / 0 Important / 0 Minor.
- R3 I1 and M1: **closed**.
- Direct regression / O_TMPFILE protocol: **PASS**.
