# Task 2.2 fresh independent object-store security review R1

- Range: `657785d355015fbb22390802167533ef542782d8..7640db1f279e8cb3f08413619f1260a07e5a0c01`
- Immutable package: `review-657785d3-7640db1f.md`
- Commit: `7640db1 feat(harness): publish immutable evidence objects`
- Authority: full task brief plus the current `DECISIONS.md` stable-topology boundary
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**
- Findings: **1 Blocker / 3 Important / 1 Minor**

## Standards — PASS

The strict range changes only the two task-owned files. `git diff --numstat` is runtime `36/0` and test `18/1`, or 54 additions, within the task ceiling (`54 <= 80`). `git diff --check` is clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found, and no review-worthy Fowler smell is introduced beyond the repository's established compact runtime/test style.

## Spec — FAIL

### B1 — same-byte reuse does not establish a durable, mode-0444 object

Runtime lines 189–192 return immediately whenever the digest leaf is a regular file with matching bytes. This path neither checks the required mode `0444` nor fsyncs the object directory. An exact-head probe changed a valid object to mode `0600`; `publish_object` returned success and left it `0600`. A second probe injected `OBJECT_DIR_FSYNC`, observed the permitted linked orphan, then replayed the identical payload while recording `os.fsync`: replay returned success with zero fsync calls.

That breaks R7's mode and object-directory durability contract and R9/R15 replay semantics. A linked object left specifically by the object-dir-fsync fault is not known durable, so matching bytes alone cannot justify a successful replay. Validate the full existing-object contract and perform the durability step before returning success.

### I1 — named temps are changed to 0444 before link, violating the stale-temp contract

Runtime lines 193–200 create the named temp as `0600`, write and fsync it, then `fchmod(..., 0444)` before `os.link`. An exact-head link interception observed the source temp at mode `0444`. A SIGKILL or other unexpected termination in that interval leaves `.<digest>.tmp.<pid>.<nonce>` mode `0444`, contrary to R15's exact requirement that unexpected-termination temps remain `0600`.

The nonce is random, creation is `O_EXCL|O_NOFOLLOW`, full writes are looped, and controlled faults clean their own temp; the mode transition is the failing part.

### I2 — bound argument errors do not precede schema errors

Runtime line 178 validates only `object_kind`, `payload` type/kind, and `fault_point`; it calls `_validate_artifact` at line 179 before `validate_state_paths` checks the remaining bound values. With the same malformed source-state payload, independent calls using `state_dir=1` or `forbidden_roots=[]` both returned `DESCRIPTOR_SCHEMA_INVALID`, not the required higher-priority `ARGUMENT_ERROR`. A payload missing `kind` is also classified as `ARGUMENT_ERROR` by the line-178 combination check rather than reaching closed-schema validation.

This violates the deterministic pre-lock order and R12's exact-code contract. All successfully bound value/container checks must be pure and complete before schema validation; malformed artifact structure must then remain `DESCRIPTOR_SCHEMA_INVALID`.

### I3 — concurrent publishers can fail during clean-store initialization

Sixteen exact-head processes publishing the same valid payload into one existing empty `state_dir` produced one `STATE_DIR_CONTRACT` failure and fifteen successes. The loser observed a missing artifact component, raced another publisher's `mkdirat`, and treated `EEXIST` as a path-contract failure. With `artifacts/v1/sha256` pre-created, 32 concurrent publishers all succeeded and left one object with no temps.

The approved boundary excludes an external same-UID actor actively renaming/moving/deleting topology; it does not exclude ordinary cooperating runtime publishers racing to create their own required directories. The object-only API intentionally has no ref lock, while hard-link no-replace supplies its object commit arbitration. Treat a concurrent `mkdirat` `EEXIST` as reopen-and-validate so clean-start publication is idempotent.

### M1 — `store-object` does not prove several mandatory invariants

Test lines 111–127 pass but do not assert the expected domain digest/path basename, temp mode, preservation of an existing same-byte inode, fsync fd types/order, directory fsync on reuse, orphan existence/replay, prelink absence, or concurrent publication. `calls` records fsync target modes but only checks `len(calls) >= 3`; the stale temp is checked once, and the final temp predicate explicitly excludes its name. Consequently all B1/I1/I3 behaviors remain green. Add direct state assertions for each task-step invariant, including controlled-temp count zero and external sentinel/tree delta zero on every failure branch.

## Confirmed behavior

- The callable is keyword-only with the specified six required keywords plus optional `fault_point`; positional/missing/unknown call shapes remain native `TypeError`. It returns an ordinary dict with exactly `{digest,object_path}` and a normalized absolute path, as the design requires.
- Valid artifacts are closed-schema checked before path creation. Canonical bytes are RFC-8785-style sorted compact UTF-8 plus one LF; the object digest uses the artifact's fixed ASCII domain and excludes that LF. Key reordering is stable.
- New-object publication uses a random 64-bit nonce, `O_EXCL|O_NOFOLLOW`, a complete-write loop, file fsync, hard-link no-replace, and object-directory fsync. Different bytes at the digest leaf return `DIGEST_COLLISION`; symlink/non-regular leaves are not followed.
- Controlled `OBJECT_LINK` and `OBJECT_DIR_FSYNC` faults return `PUBLISH_PRECOMMIT_FAILED` and `PUBLISH_OBJECT_ORPHANED`; this invocation's temp is removed. Object-directory stale temps are neither consumed nor automatically removed, and an external sentinel remained unchanged.
- A 200-call reuse loop had zero `/proc/self/fd` delta. Pre-created-topology concurrent publication left one object and no temp files.
- The red evidence records the required missing-publisher failure. The strict range contains no AOSP access, envsetup, lunch, build, sync, fetch/clone, package, flash, or download operation.

## Executable evidence

All dynamic checks ran from an archive-isolated exact-head tree at `/tmp/aosp-00a-2.2-review.MNWXWM`, commit `7640db1f279e8cb3f08413619f1260a07e5a0c01`. No real AOSP path was inspected.

```text
python3 common/tests/test_seed_contract_runtime.py canonical-core concurrent-core evidence-schema seed-schema terminal-golden state-paths store-object
PASS canonical-core
PASS concurrent-core
PASS evidence-schema
PASS seed-schema
PASS terminal-golden
PASS state-paths
PASS store-object

independent mode/priority/replay probe
temp_mode_at_link 0o444
reused_mode 0o600
state_dir DESCRIPTOR_SCHEMA_INVALID
forbidden_roots DESCRIPTOR_SCHEMA_INVALID
orphan_fault PUBLISH_OBJECT_ORPHANED
orphan_exists_mode True 0o444
replay_fsync_calls 0
fd_delta_200_reuse 0

independent clean-start concurrency probe
concurrency_rcs [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
object_names ['8e8933178818df78d026f6e37210fdb4f47e81e6ee66d5cf4459971e880f2e32']

independent pre-created-topology concurrency probe
failures []
temp_leftovers []

bash common/tests/test-harness.sh
RESULT PASS  shared Harness regression suite

bash common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约

bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
final: RESULT PASS

git diff --check 657785d355015fbb22390802167533ef542782d8..7640db1f279e8cb3f08413619f1260a07e5a0c01
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 1 Blocker / 3 Important / 1 Minor.
- Worst Standards issue: none.
- Worst Spec issue: the idempotent same-byte path can report success without establishing the required durable mode-0444 object.
