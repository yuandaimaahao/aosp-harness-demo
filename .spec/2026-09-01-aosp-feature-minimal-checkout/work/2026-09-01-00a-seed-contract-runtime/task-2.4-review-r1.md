# Task 2.4 fresh independent atomic-ref security review R1

- Range: `c5b7bfcec2372d03bcbb0be6f9b963e9ac86c6a1..abc4a8fac362426801f6337d3beef59fd025a622`
- Immutable package: `review-c5b7bfce-abc4a8fa.md`
- Commit: `abc4a8f feat(harness): atomically publish locked seed refs`
- Authority: updated task 2.4 brief plus current `DECISIONS.md` stable-topology boundary
- Exact head under test: `abc4a8fac362426801f6337d3beef59fd025a622`
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**
- Findings: **0 Blocker / 3 Important / 1 Minor**

## Standards — PASS

The strict range modifies exactly the two task-owned files. `git diff --numstat` is runtime `54/2` and tests `17/1`: 71 additions, within the task ceiling (`71 <= 75`). `git diff --check` is clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found, and no separate review-worthy Fowler smell is introduced beyond the repository's already-established compact runtime/test style.

## Spec — FAIL

### I1 — invalid publisher combinations lose the required `ARGUMENT_ERROR` priority

Runtime line 305 calls `_validate_artifact(payload)` before checking the allowed `(object_kind, payload.kind, ref_kind)` mapping. The brief fixes runtime pre-lock priority as bound-value/combination `ARGUMENT_ERROR` before `DESCRIPTOR_SCHEMA_INVALID`. At exact head, `object_kind="wrong", ref_kind="wrong", payload={}` returned `DESCRIPTOR_SCHEMA_INVALID`; it must stop on the invalid combination with `ARGUMENT_ERROR` without attempting schema dispatch.

Move all independently decidable kind/ref/semantic combination checks ahead of payload schema validation. Keep a schema-valid `object_kind != payload.kind` case as `ARGUMENT_ERROR`, and add the mixed invalid-combination + malformed-payload assertion so this ordering cannot regress.

### I2 — intended evidence is observed before an existing ref, reversing the locked publisher priority

Runtime line 307 executes `_evidence(objectfd, payload)` before `_existing_ref(...)`. The design sequence requires the publisher, once locked, to first observe the existing ref and its primary/evidence closure; the requirements say an existing publisher ref follows the resolver ordering, with corrupt ref bytes preceding missing/corrupt objects. An exact-head mixed probe with existing `b"bad"` ref bytes and one missing intended terminal evidence digest returned `ARTIFACT_MISSING` and never classified the existing ref. The required result is `REF_CORRUPT`.

Validate the existing ref/old closure first under the lock, then validate the intended payload's complete seed/terminal closure, and only then enter `DIGEST_CHECK`/object publication. Neither validation path may create an object or ref temp.

### I3 — a later locked publisher never performs the required stale ref-temp cleanup

R15 requires unexpected `.*.tmp.<pid>.<nonce>` ref-dir leftovers to be mode 0600, ignored by resolution, and best-effort cleaned only by a later invocation holding the same ref lock. Runtime lines 306–315 create and clean only the current invocation's `temp`; there is no locked stale-temp scan. A successful publish, followed by creation of mode-0600 `.pass.tmp.999999999.0123456789abcdef`, followed by a successful locked replay left that stale file present.

Under the acquired adjacent lock, best-effort unlink only stale names belonging to that exact ref and matching the fixed temp grammar. Do not scan or clean object-dir temps, and do not let cleanup failure change the publication result.

### M1 — exceptional directory-close cleanup can leak the remaining descriptor graph

The publisher finally block closes `refdir` and `lock` defensively, but lines 330 then call `_drop(objects); _drop(nodes)`, whose list-comprehension stops on the first `os.close` error. A probe forced the first final object-directory close to raise `EIO`: `publish` leaked six directory descriptors and exposed raw `OSError` after the ref was already durable. This is inconsistent with the resolver's per-fd best-effort cleanup and weakens the task's all-path fd-cleanup claim.

Close every saved fd independently in the finalizer and suppress cleanup-only close/unlock errors so they cannot replace an already-determined success or `ContractError`. Add an injected final-close failure assertion with zero fd delta.

## Confirmed behavior

- The API is keyword-only and returns exact ordinary-dict keys `{digest,object_path,ref_path,semantic_exit}` with normalized absolute paths. Valid terminal/terminal-report exit 20 and seed/env-pass exit 0 paths both publish and resolve.
- The adjacent no-follow regular 0600 effective-UID lock is acquired nonblocking before any ref/object leaf read and is held through ref replacement/fsync. Same-ref concurrency produced only the expected success/result or `REF_BUSY`; 64 different refs racing the same object all succeeded with one digest.
- Intended seed/terminal schema and evidence closure run before any object/ref temp. Existing ref missing is accepted; ordinary existing/corrupt ref, missing/corrupt object, collision, and lock failures leave ref/object bytes unchanged, apart from I2's mixed-priority error code.
- Object durability precedes ref publication. Ref temp creation is same-directory, random/O_EXCL/no-follow, exact mode 0600, complete-write safe, file-fsynced, atomically replaced, and followed by ref-directory fsync. A forced one-byte-at-a-time write still produced exact canonical ref bytes.
- `OBJECT_LINK` gives `PUBLISH_PRECOMMIT_FAILED` with no new object; `OBJECT_DIR_FSYNC` gives `PUBLISH_OBJECT_ORPHANED` with the intended immutable object and old ref; post-replace `REF_RENAME`/`REF_DIR_FSYNC` give `REF_DURABILITY_UNCERTAIN`. A real forced ref-directory `fsync` `EIO` left an intended ref that resolved and replayed idempotently.
- Controlled faults remove the current invocation's named ref temp, and no tested fault created a dangling ref. Resolver ignores temp names. I3 remains for pre-existing stale ref temps.
- The strict diff contains no real AOSP access and no envsetup, lunch, build, sync, fetch/clone, package, flash, or download operation.

## Test audit

The committed `ref-publish` case covers ordinary missing/existing refs, output bytes/modes/result keys, the four named fault points, replay, one corrupt ref, seed and terminal publication, same-ref contention, sentinel preservation, controlled-temp absence, and final resolvability. It does not cover the mixed argument/schema priority (I1), existing-ref versus intended-evidence priority (I2), stale ref-temp recovery (I3), exceptional finalizer cleanup (M1), or syscall-level ref write/fsync/replace ordering. Those omissions allowed all four findings to remain green.

## Executable evidence

All dynamic checks ran from archive-isolated exact-head tree `/tmp/aosp-00a-2.4-r1.ObrsFu`. No real AOSP path was inspected.

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

bash common/tests/test-harness.sh
RESULT PASS  shared Harness regression suite

bash common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约

bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
RESULT PASS

independent exact-head probes
mixed_invalid_mapping_schema DESCRIPTOR_SCHEMA_INVALID
corrupt_ref_plus_missing_intended_evidence ARTIFACT_MISSING ref b'bad'
stale_ref_temp_after_locked_replay True 0o600
partial_write_complete True
actual_ref_fsync_fault REF_DURABILITY_UNCERTAIN resolves True replay 20
different_ref_same_object_concurrency 1 {'083e2b7cee3b6d5737dce9d1321ac961ebafec60e05f4eba4a090d48ae875d14'} temps 0
forced_final_dir_close OSError:[Errno 5] forced final close fd_delta 6

git diff --check c5b7bfcec2372d03bcbb0be6f9b963e9ac86c6a1..abc4a8fac362426801f6337d3beef59fd025a622
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 0 Blocker / 3 Important / 1 Minor.
- Worst Standards issue: none.
- Worst Spec issue: the locked publisher reverses existing-ref versus intended-evidence observation priority, returning the wrong stable error code before it classifies the existing ref.
