# Task 2.2 fresh independent object-store security review R3

- Range: `657785d355015fbb22390802167533ef542782d8..d65d12075f6d6cf7fcf45e3c924bcabc52a74eff`
- Immutable package: `review-657785d3-d65d1207.md`
- Commits: `7640db1 feat(harness): publish immutable evidence objects`; `ba8f961 fix(harness): harden immutable object replay`; `d65d120 fix(harness): atomically publish immutable objects`
- Authority: full task brief plus current `DECISIONS.md` stable-topology boundary
- Exact head under test: `d65d12075f6d6cf7fcf45e3c924bcabc52a74eff`
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**
- Findings: **0 Blocker / 1 Important / 1 Minor**

## Standards — PASS

The strict cumulative range changes only the two task-owned files. `git diff --numstat` is runtime `40/1` and test `29/1`: 69 additions and 71 total changed lines, within the task ceiling (`71 <= 80`). `git diff --check` is clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found, and no separate review-worthy Fowler smell is introduced.

## Spec — FAIL

### I1 — the no-replace race recovery path leaks raw filesystem errors

Runtime lines 210–212 catch the `linkat` `EEXIST` result, but the matching-object `read(digest)` and following directory `fsync` execute inside that exception handler. Any `OSError` from either durability operation therefore bypasses the surrounding `except OSError` and escapes the stable API unchanged. An exact-head probe forced the ordinary sequence “initially absent → peer creates matching 0444 object → this invocation gets `EEXIST` → existing-object fsync gets `EIO`”; `publish_object` returned raw `OSError: [Errno 5]`, with no fd leak.

The same object/file or directory fsync failure on the initial-reuse path is deterministically translated to `PUBLISH_PRECOMMIT_FAILED`. The race path must do likewise: `ContractError` is the only expected failure carrier, and R12 plus the commit-stage matrix do not permit a raw exception (which a future CLI wrapper would misreport as `RUNTIME_INTERNAL`). Put the EEXIST recheck/durability work back under translation, preserving `DIGEST_COLLISION` for a mismatching leaf.

### M1 — `store-object` still does not prove the exact commit/error matrix

Test line 120 checks that the first two fsync targets are regular files, but not that their modes are exactly 0600 then 0444; it observes `O_TMPFILE` but not `linkat` no-replace flags/return handling. The collision snapshot at lines 125–126 records only path names, so it cannot prove existing collision bytes/mode were unchanged. It also has no EEXIST-loser durability-error case, allowing I1 to remain green. Add exact mode-at-fsync/link assertions, existing-byte preservation, and EEXIST recheck failure translation without weakening the 80-line ceiling.

## Prior-finding verification

- R1 B1: **closed**. Same-byte reuse verifies exact regular/0444/canonical bytes, fsyncs the object and directory, preserves the inode, and replays an object-dir-fsync orphan successfully.
- R1 I1: **closed**. Publication now uses an anonymous same-directory `O_TMPFILE`; unexpected termination before link leaves no named temp, and the inode is 0444 before it becomes visible.
- R1 I2: **closed**. Bound argument/container errors precede schema validation; malformed envelopes remain `DESCRIPTOR_SCHEMA_INVALID`; a valid kind mismatch is `ARGUMENT_ERROR`.
- R1 I3: **closed**. Racing `mkdirat` `EEXIST` is reopened and validated; clean-start concurrent publication succeeds.
- R1 M1: **partially closed** by the expanded assertions; M1 above lists the remaining mandatory gaps.
- R2 B1: **closed**. Digest leaves are classified first with nonblocking `O_PATH|O_NOFOLLOW`; FIFO, directory, and symlink probes all returned `DIGEST_COLLISION` without touching the sentinel.
- R2 B2: **closed**. Exact sequence is anonymous 0600 inode → complete write → file fsync → fchmod 0444 → file fsync → link; chmod failure or termination before link leaves no digest leaf.
- R2 I1: **closed**. Valid `object_kind`/payload-kind mismatch returns `ARGUMENT_ERROR` before path mutation.
- R2 I2: **closed**. There is no finite polling protocol. A publisher paused after successful link and a same-digest peer both succeeded; the visible object remained canonical and 0444.
- R2 M1: **closed**. `stat.S_IMODE(...) == 0o444` rejects setuid/setgid/sticky additions; mode 01444 returned `DIGEST_COLLISION`.
- R2 M2: **partially closed**. FIFO, pre-link termination, paused concurrency, kind mismatch, special bits, and actual changed bytes at the same digest leaf are now exercised; exact commit instrumentation and I1 remain absent.

## Confirmed behavior

- The publisher is keyword-only, accepts only the three evidence kinds, returns exact ordinary-dict keys `{digest,object_path}`, and produces a normalized absolute digest path with RFC-8785 canonical bytes plus LF.
- The normal commit uses same-directory `O_TMPFILE` mode 0600, complete writes, file fsync, exact 0444, second file fsync, libc `linkat(..., AT_EMPTY_PATH)` with no replacement, and object-directory fsync. On this unprivileged host the first call returned `-1/ENOENT`, the `/proc/self/fd` `AT_SYMLINK_FOLLOW` fallback returned 0, and stale errno was harmless because success is decided by the return value.
- Forced unsupported `O_TMPFILE` (`EOPNOTSUPP`) and forced non-collision `linkat` failure (`EXDEV`) both returned `PUBLISH_PRECOMMIT_FAILED`, left no object/temp leaf, and leaked no fd. `EEXIST` collision arbitration and exact errno handling otherwise work.
- `OBJECT_LINK` leaves no object and returns `PUBLISH_PRECOMMIT_FAILED`; `OBJECT_DIR_FSYNC` leaves an immutable 0444 orphan and returns `PUBLISH_OBJECT_ORPHANED`; replay succeeds after file and directory fsync. Collision overrides a lower-priority injected fault and preserves the existing bytes.
- Atomic-ready monitoring over 64 concurrent distinct publications observed no partial bytes, non-regular leaf, or non-0444 mode. A 300-call reuse loop had zero `/proc/self/fd` delta.
- The strict range contains no AOSP access, envsetup, lunch, build, sync, fetch/clone, package, flash, or download operation.

## Executable evidence

All dynamic checks ran from archive-isolated exact-head tree `/tmp/aosp-00a-2.2-r3.KqFDqx`. No real AOSP path was inspected.

```text
PYTHONDONTWRITEBYTECODE=1 python3 common/tests/test_seed_contract_runtime.py canonical-core concurrent-core evidence-schema seed-schema terminal-golden state-paths store-object
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
priority_argument_and_schema ARGUMENT_ERROR DESCRIPTOR_SCHEMA_INVALID
kind_mismatch ARGUMENT_ERROR
normal_result exact_keys=True digest_path=True mode=0444 canonical=True
reuse inode_preserved=True fd_delta=0
special_bits/FIFO/directory/symlink DIGEST_COLLISION
prelink_fault PUBLISH_PRECOMMIT_FAILED object_absent=True
orphan_fault PUBLISH_OBJECT_ORPHANED object_present=True mode=0444
orphan_replay SUCCESS
linkat_actual [(-1, ENOENT, AT_EMPTY_PATH), (0, stale_ENOENT, AT_SYMLINK_FOLLOW)]
unsupported_tmpfile PUBLISH_PRECOMMIT_FAILED names=[] fd_delta=0
linkat_errno_failure PUBLISH_PRECOMMIT_FAILED names=[]
eexist_recheck_fsync_failure OSError:[Errno 5] fd_delta=0
atomic_ready publications=64 objects=64 invalid_observations=[]
paused_after_link first=SUCCESS second=SUCCESS mode=0444 canonical=True
collision_over_fault DIGEST_COLLISION bytes_preserved=True

git diff --check 657785d355015fbb22390802167533ef542782d8..d65d12075f6d6cf7fcf45e3c924bcabc52a74eff
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 0 Blocker / 1 Important / 1 Minor.
- Worst Standards issue: none.
- Worst Spec issue: a durability error after losing the atomic no-replace race escapes the stable API as raw `OSError` instead of the required deterministic contract code.
