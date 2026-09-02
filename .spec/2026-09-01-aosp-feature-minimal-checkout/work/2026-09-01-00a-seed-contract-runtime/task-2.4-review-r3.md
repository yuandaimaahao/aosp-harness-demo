# Task 2.4 fresh independent atomic-ref security review R3

- Range: `c5b7bfcec2372d03bcbb0be6f9b963e9ac86c6a1..e577c24a26525a372bb2827b567440a2d186eb33`
- Immutable package: `review-c5b7bfce-e577c24a.md`
- Commits: `abc4a8f feat(harness): atomically publish locked seed refs`; `2b9dc53 fix(harness): harden locked ref publication`; `e577c24 fix(harness): preserve ref publish precommit state`
- Authority: task 2.4 brief plus current `DECISIONS.md` stable-topology boundary
- Exact head under test: `e577c24a26525a372bb2827b567440a2d186eb33`
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**
- Findings: **0 Blocker / 1 Important / 0 Minor**

## Standards — PASS

The strict range modifies exactly the two task-owned files. `git diff --numstat` is runtime `56/4` and tests `17/1`: 73 additions, within the task ceiling (`73 <= 75`). `git diff --check` is clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found, and no separate review-worthy Fowler smell is introduced beyond the repository's established compact runtime/test style.

## Spec — FAIL

### I1 — stale-temp cleanup can close an unrelated concurrently reused descriptor

At runtime line 310, the stale candidate fd is appended to `objects`, then immediately closed by `_close(p)`. The finalizer at line 330 later passes the retained integer to `_drop(objects...)` and closes it a second time. File descriptors are process-wide and may be reused as soon as the first close completes; under the in-scope same-process concurrent publisher model, another thread can acquire that integer before this invocation reaches its finalizer, after which this publisher closes the other thread's live descriptor.

An exact-head probe made the reuse deterministic: the stale candidate opened as fd 17, `_close(p)` released it, an unrelated `/dev/null` open immediately reused fd 17, publication returned semantic 20, and the final `_drop` left the unrelated fd as `EBADF`. This violates R8's stable-topology concurrent-publisher safety and the design's all-path descriptor cleanup rule; depending on the victim fd, it can turn a concurrent publish into a spurious failure or corrupt its commit ordering.

Do not retain a descriptor after closing it. Inspect each stale candidate with a local `try/finally: _close(p)` and remove `objects.append((p,""))`; alternatively, transfer ownership to the outer graph and do not close it in the scan. Add a regression that forces fd-number reuse between stale inspection and the publisher finalizer and asserts the replacement descriptor remains live.

## Prior-finding closure audit

- R1 I1 / R2 I1 mapping priority: **closed**. A present string payload kind inconsistent with `object_kind` now returns `ARGUMENT_ERROR` before schema dispatch; missing/non-string kind remains `DESCRIPTOR_SCHEMA_INVALID`.
- R1 I2 existing-ref priority: **closed**. Corrupt existing ref bytes mask missing intended evidence with `REF_CORRUPT`.
- R1 I3 / R2 I2 stale-cleanup placement: **closed**. Cleanup follows successful object publication; `DIGEST_COLLISION` preserves the stale temp, object, ref, and sentinel snapshot.
- R1 M1 / R2 M1 leak handling: **partial**. Forced inner object-dir close and stale-candidate `fstat` errors no longer leak descriptors or replace success, but the successful stale-candidate path introduces I1's double-close race.

## Confirmed publication behavior

- The keyword-only API returns exact ordinary-dict keys and normalized absolute paths. Valid terminal/terminal-report exit 20 and seed/env-pass exit 0 publish and resolve.
- The adjacent no-follow regular 0600 effective-UID lock is acquired nonblocking before ref/object observation and held through ref replacement/fsync. Legal contention returns `REF_BUSY`; existing-ref and intended-evidence errors follow the required locked priority.
- Schema/evidence validation and collision checking precede publication mutations. Missing ref is accepted; corrupt ref/object/evidence, invalid combinations, and collision preserve the required object/ref/temp/sentinel bytes.
- Canonical object bytes are mode 0444 and durable before the same-directory 0600 canonical ref temp is file-fsynced and atomically replaced; the ref directory is then fsynced. One-byte writes still produced exact ref bytes.
- `OBJECT_LINK`, `OBJECT_DIR_FSYNC`, `REF_RENAME`, and `REF_DIR_FSYNC` retain their required precommit/orphan/durability codes and no-dangling-ref outcomes. A real injected ref-directory `fsync` error returned `REF_DURABILITY_UNCERTAIN`; the intended ref resolved and replay returned semantic 20.
- Thirty-two different refs racing the same object all succeeded with one digest, zero dangling refs, and no unexpected codes. Same-ref contention remains success/`REF_BUSY` only.
- Controlled faults remove the current invocation's ref temp. Exact-name stale cleanup occurs only while holding the adjacent lock and after digest success; other-ref, symlink, and wrong-mode candidates remain excluded. I1 prevents a full concurrency/cleanup PASS.
- The strict diff contains no real AOSP access and no envsetup, lunch, build, sync, fetch/clone, package, flash, or download operation.

## Test audit and executable evidence

All dynamic checks ran from archive-isolated exact-head tree `/tmp/aosp-00a-2.4-r3.Zaw13i`; no real AOSP path was inspected.

```text
canonical-core concurrent-core evidence-schema seed-schema terminal-golden
state-paths store-object ref-resolve ref-publish: all nine PASS
test-harness.sh: RESULT PASS  shared Harness regression suite
check-parity.sh: PARITY PASS  Claude/Codex 共享同一公共契约
verify-sidebar.sh --demo: RESULT PASS

independent exact-head probes
mapping_priority ARGUMENT_ERROR
old_ref_priority REF_CORRUPT
collision_snapshot DIGEST_COLLISION preserved=True
inner_close_cleanup SUCCESS fd_delta=0
stale_fstat_cleanup SUCCESS fd_delta=0 stale_preserved=True
actual_ref_fsync REF_DURABILITY_UNCERTAIN resolves=True replay=20
one_byte_write exact=True
different_ref_same_object successes=32 errors=[] digests=1 dangling=0
lock_contention REF_BUSY
stale_fd_reuse publication=SUCCESS stale_fd=17 replacement_alive=False
git diff --check: exit 0; stdout/stderr empty
```

The committed case now covers the prior error-priority, collision-snapshot, and injected leak findings. Its fd-count assertions cannot detect closing a descriptor that another thread opened under the reused number, so I1 remains green.

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 0 Blocker / 1 Important / 0 Minor.
- Worst Standards issue: none.
- Worst Spec issue: stale-temp cleanup can close another thread's newly reused descriptor during an otherwise successful publish.
