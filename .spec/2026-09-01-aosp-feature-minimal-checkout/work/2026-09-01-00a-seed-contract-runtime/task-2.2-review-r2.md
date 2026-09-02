# Task 2.2 fresh independent object-store security review R2

- Range: `657785d355015fbb22390802167533ef542782d8..ba8f961064fbc20f9de0c607cc58944b7d6c27fa`
- Immutable package: `review-657785d3-ba8f9610.md`
- Commits: `7640db1 feat(harness): publish immutable evidence objects`; `ba8f961 fix(harness): harden immutable object replay`
- Authority: updated task brief plus current `DECISIONS.md` stable-topology boundary
- Exact head under test: `ba8f961064fbc20f9de0c607cc58944b7d6c27fa`
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**
- Findings: **2 Blocker / 2 Important / 2 Minor**

## Standards — PASS

The strict cumulative range changes only the two task-owned files. `git diff --numstat` is runtime `46/1` and test `25/1`, or 71 additions, within the task ceiling (`71 <= 80`). `git diff --check` is clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found, and no separate review-worthy Fowler smell was introduced beyond the repository's established compact runtime/test style.

## Spec — FAIL

### B1 — a static FIFO at the digest leaf blocks forever before the regular-file check

Runtime lines 185–189 call `os.open(name, O_RDONLY|O_NOFOLLOW)` and only then inspect `fstat`. `O_NOFOLLOW` protects a symlink but does not make opening a FIFO nonblocking. An exact-head subprocess with a mode-0444 FIFO at the expected 64-hex leaf produced no output and exceeded a one-second timeout.

Static non-regular leaves are explicitly in the R5/R6 threat model. This neither fails closed nor returns a deterministic R12 contract error; a pre-existing in-scope leaf can indefinitely deny publication. Open in a way that cannot block on a non-regular inode, verify the inode type, and only then read regular-file bytes.

### B2 — post-link failure or termination leaves a mutable digest object and poisons replay

Runtime line 208 links the mode-0600 temp to the final digest, unlinks the temp name, and only then changes the shared inode to 0444. Injecting an `OSError` into that final `fchmod` returned `PUBLISH_OBJECT_ORPHANED` while leaving exact canonical bytes at the digest leaf with mode 0600 and no temp; replay returned `DIGEST_COLLISION`. A subprocess terminating at the same point likewise left only the mode-0600 digest leaf.

The R1 temp fix correctly keeps the temp 0600 through link/name removal, but the final digest is now observable and persistent before it is immutable. That violates R7's mode-0444 object contract and R9/R15's immutable-orphan and idempotent-replay guarantees. A failure before mode/final file durability is established must not be classified or retained as a committed immutable orphan.

### I1 — a valid payload whose kind disagrees with `object_kind` is published successfully

Runtime line 181 validates that `object_kind` is one of the three enums, but no longer enforces `object_kind == payload.kind`; line 182 dispatches schema and domain solely from the payload. An exact-head call with `object_kind="trace"` and a valid `source_state` payload returned success and stored the source-state object.

The stable API requires the caller-provided full envelope to match `object_kind` and requires unique dispatch by `object_kind`. Reject the mismatch without regressing the corrected precedence for a malformed/missing payload kind.

### I2 — the fixed 1,000-yield mode poll can reject a cooperating publisher

Runtime lines 193–198 treat matching mode-0600 bytes as transient for only 1,000 `sched_yield` iterations, then return `DIGEST_COLLISION`. In an exact-head two-thread probe, the first publisher was paused at its final `fchmod(0444)` after linking; the second publisher returned `DIGEST_COLLISION`, then the first completed successfully.

This is ordinary stable-topology cooperating publication, not the excluded hostile rename/move/delete actor. R7 same-byte idempotence and the approved clean-store concurrency boundary cannot depend on the winning publisher being scheduled within an arbitrary spin count. Use a commit protocol or coordination rule with a correctness-preserving terminal state.

### M1 — reuse accepts permission modes other than exact 0444

Runtime line 190 compares `st_mode & 0o777`, which ignores setuid, setgid, and sticky bits. After changing an otherwise valid object to mode `01444`, exact-head replay returned success and preserved `01444`. R7 and the data model require mode 0444, not merely permission bits 0444; compare the full permission mode (for example, `stat.S_IMODE`) against 0444.

### M2 — `store-object` still is not an exact comprehensive regression case

Test lines 111–134 substantially improve R1 coverage, including normal durable replay, link-time temp mode, controlled faults, and clean-start threads. They do not cover a blocking FIFO/non-regular leaf, post-link `fchmod`/termination failure, a paused cooperating publisher, valid `object_kind`/payload-kind mismatch, special mode bits, or an actual same-digest/different-bytes leaf (line 126 changes only mode while retaining the same bytes). All implementation failures above therefore remain green, and the task's explicit same/different-digest/collision coverage is incomplete.

## R1 finding verification

- R1 B1: **partially closed**. Normal same-byte reuse now validates ordinary mode 0444, fsyncs the object and directory, preserves the inode, and replays the controlled orphan; B2 shows fault/termination replay is still broken.
- R1 I1: **closed for the named temp invariant**. Link interception observed 0600 and the temp name is removed before chmod; B2 is the resulting incomplete-object window.
- R1 I2: **closed for the reported precedence probes**. Invalid bound argument containers return `ARGUMENT_ERROR`; malformed payload with otherwise valid arguments returns `DESCRIPTOR_SCHEMA_INVALID`. I1 is a separate valid-envelope combination regression.
- R1 I3: **closed for ordinary clean-start racing mkdir**. Ten isolated rounds of 24 processes each all succeeded with one object and zero temps. I2 shows publication is not correct when the winner is paused after link.
- R1 M1: **partially closed**. The named assertions were added, but M2 lists mandatory uncovered states.

## Confirmed behavior

- Valid publication produces the fixed domain digest/path, canonical JSON plus LF, normal mode 0444, complete writes, file fsync, hard-link no-replace, final file fsync, and object-directory fsync.
- Normal matching-object reuse preserves the inode and performs file plus directory fsync. A 300-call exact-head reuse loop had zero `/proc/self/fd` delta.
- `OBJECT_LINK` and `OBJECT_DIR_FSYNC` produce `PUBLISH_PRECOMMIT_FAILED` and `PUBLISH_OBJECT_ORPHANED`; controlled temps are removed, an object-dir stale temp is not consumed, and the external sentinel remains unchanged.
- Pure bound argument checks precede descriptor schema checks, and schema validation precedes state-path creation. Existing symlinks are not followed. Clean-start initialization tolerates cooperating `mkdirat` `EEXIST` races.
- Callable shape remains keyword-only and result keys are exactly `{digest,object_path}` with a normalized absolute object path.

## Executable evidence

All dynamic checks ran from archive-isolated exact-head tree `/tmp/aosp-00a-2.2-r2.YraouT`. No real AOSP path was inspected and no AOSP setup/build/sync/download command was run.

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
fifo_leaf_result TIMEOUT_AFTER_1S
final_chmod_fault PUBLISH_OBJECT_ORPHANED [... mode 0o600, canonical bytes True] temps []
final_chmod_fault_replay DIGEST_COLLISION
unexpected_termination_rc 91
unexpected_termination_leaves [... mode 0o600]
valid_object_kind_payload_mismatch SUCCESS
paused_cooperating_publishers first ['SUCCESS'] second DIGEST_COLLISION
special_mode_reuse 0o1444 SUCCESS 0o1444
priority_state_and_schema ARGUMENT_ERROR
priority_schema_only DESCRIPTOR_SCHEMA_INVALID
fd_delta_300_reuse 0
clean_start_process_concurrency_rounds 10 publishers_each 24 failures []

git diff --check 657785d355015fbb22390802167533ef542782d8..ba8f961064fbc20f9de0c607cc58944b7d6c27fa
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 2 Blocker / 2 Important / 2 Minor.
- Worst Standards issue: none.
- Worst Spec issues: an in-scope FIFO leaf can hang the publisher indefinitely, and interruption in the post-link/pre-chmod window leaves a mutable final digest object that cannot be replayed idempotently.
