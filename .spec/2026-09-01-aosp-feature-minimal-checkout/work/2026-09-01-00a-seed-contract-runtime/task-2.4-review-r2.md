# Task 2.4 fresh independent atomic-ref security review R2

- Range: `c5b7bfcec2372d03bcbb0be6f9b963e9ac86c6a1..2b9dc53616df17a59f107041498a7c898694808b`
- Immutable package: `review-c5b7bfce-2b9dc536.md`
- Commits: `abc4a8f feat(harness): atomically publish locked seed refs`; `2b9dc53 fix(harness): harden locked ref publication`
- Authority: task 2.4 brief plus current `DECISIONS.md` stable-topology boundary
- Exact head under test: `2b9dc53616df17a59f107041498a7c898694808b`
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**
- Findings: **0 Blocker / 2 Important / 1 Minor**

## Standards — PASS

The strict range modifies exactly the two task-owned files. `git diff --numstat` is runtime `56/3` and tests `17/1`: 73 additions, within the task ceiling (`73 <= 75`). `git diff --check` is clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found, and the hardening introduces no separate review-worthy Fowler smell beyond the repository's established compact runtime/test style.

## Spec — FAIL

### I1 — the R1 mapping-priority fix remains incomplete for an independently visible payload kind

Runtime line 306 checks `(object_kind, ref_kind)`, then fully validates the payload, and only afterward checks `payload["kind"] == object_kind`. The deterministic pre-lock order puts bound-value/combination `ARGUMENT_ERROR` before `DESCRIPTOR_SCHEMA_INVALID`, and R1 explicitly required every independently decidable kind/ref combination to move ahead of schema dispatch. At exact head, a terminal/terminal call with `payload={"schema_version":1,"kind":"source_state"}` returned `DESCRIPTOR_SCHEMA_INVALID`; because the string kind already proves the mapping inconsistent, it must return `ARGUMENT_ERROR` regardless of the malformed source-state body.

Keep missing/non-string `payload.kind` as schema-invalid, but reject a present string kind that differs from `object_kind` before `_validate_artifact`. Add both malformed-body and schema-valid mismatched-kind assertions. The added `object_kind="wrong", ref_kind="wrong", payload={}` assertion proves only the easier pair mismatch.

### I2 — stale ref-temp cleanup mutates state before `DIGEST_CHECK` can report collision

Runtime lines 309–312 remove old same-ref temps before line 313 calls `_publish_object`, whose first object observation performs the digest collision check. R12 and the state machine require a `DIGEST_COLLISION` pre-publish failure to leave object/ref/temp/sentinel state unchanged. A fresh exact-head probe installed a 0444 wrong-bytes file at the intended digest and a valid mode-0600 `.pass.tmp.999999999.0123456789abcdef`; `publish` returned `DIGEST_COLLISION` but deleted the stale temp.

Perform locked stale cleanup only after the intended object's digest check has succeeded (moving it after a successful `_publish_object` return is sufficient). Preserve the current exact same-ref regex, `O_NOFOLLOW`, regular-file, and 0600 filters. Add a collision snapshot assertion covering the stale temp as well as object/ref/sentinel bytes.

### M1 — nested cleanup errors can still leak descriptors after the R1 finalizer fix

The new `_drop` closes each saved descriptor independently, so the R1 outer `objects/nodes/refdir/lock` failure is fixed. However, `_publish_object` line 280 still calls raw `os.close(fd)` before line 281 `_drop(nodes)`. A forced close error on its non-`O_PATH` object-directory fd after object durability returned `PUBLISH_OBJECT_ORPHANED`, left the ref absent, and leaked seven directory descriptors. The new stale scan has the same shape at line 311: if `os.fstat(p)` raises, `_close(p)` is skipped; a probe completed publication successfully with a one-fd delta.

Make every acquired fd participate in a `finally` that cannot prevent later cleanup. In particular, use `_close(fd)` before `_drop(nodes)` and wrap stale-probe `fstat` in `try/finally: _close(p)`. Extend the injected cleanup test to target both nested object publication and stale-probe inspection, not only the outer ref-directory close.

## R1 closure audit

- I1 mapping priority: **partial**. Invalid object/ref pairs now precede schema validation; a present mismatched payload kind does not.
- I2 existing-ref priority: **closed**. Under the lock, `_existing_ref` validates the old ref, primary object, and evidence closure before intended evidence. Corrupt old ref bytes mask missing intended evidence with `REF_CORRUPT`.
- I3 stale cleanup: **partial**. Exact same-ref cleanup exists and safely preserves symlinks, wrong-mode regular files, and other-ref names, but its pre-digest placement violates zero-change collision handling.
- M1 finalizer: **partial**. The outer graph is robust; nested object-dir and stale-probe paths still leak on injected cleanup errors.

## Confirmed publication behavior

- The keyword-only API returns exact ordinary-dict keys and normalized absolute paths. Valid terminal/terminal-report exit 20 and seed/env-pass exit 0 publish and resolve.
- The adjacent lock is opened no-follow, verified regular/effective-UID/0600, acquired nonblocking before ref/object observation, and held through ref-dir fsync. Legal contention returns `REF_BUSY`; a lock symlink returns `OUT_REF_CONTRACT` without damaging the ref.
- Existing ref/primary/evidence closure precedes intended closure; intended closure precedes digest/object publication. Missing ref is accepted. Corrupt existing ref/object/closure and missing evidence do not create object/ref temps.
- Object bytes are canonical-plus-LF, mode 0444, hard-linked no-replace and directory-fsynced before the 0600 canonical ref temp is file-fsynced, atomically replaced, and ref-directory-fsynced. One-byte writes still produced exact ref bytes.
- Controlled `OBJECT_LINK`, `OBJECT_DIR_FSYNC`, `REF_RENAME`, and `REF_DIR_FSYNC` routes retain their required codes and no-dangling-ref outcomes. A real injected ref-directory `fsync` error returned `REF_DURABILITY_UNCERTAIN`; the intended ref resolved and replay returned semantic 20.
- Sixty-four different refs racing the same object all succeeded with one digest, zero dangling refs, and zero temps. Same-ref contention remains success/`REF_BUSY` only in the committed case.
- Stale cleanup is limited to the exact ref name and fixed temp grammar. Static symlink and mode-0640 candidates were preserved; a same-ref regular 0600 candidate was removed, and another ref's 0600 candidate was preserved.
- The strict diff contains no real AOSP access and no envsetup, lunch, build, sync, fetch/clone, package, flash, or download operation.

## Test audit and executable evidence

All dynamic checks ran from archive-isolated exact-head tree `/tmp/aosp-00a-2.4-r2.9PIvAe`; no real AOSP path was inspected.

```text
canonical-core concurrent-core evidence-schema seed-schema terminal-golden
state-paths store-object ref-resolve ref-publish: all nine PASS
test-harness.sh: RESULT PASS  shared Harness regression suite
check-parity.sh: PARITY PASS  Claude/Codex 共享同一公共契约
verify-sidebar.sh --demo: RESULT PASS

independent exact-head probes
mismatched_kind_malformed_body DESCRIPTOR_SCHEMA_INVALID
collision_stale_temp DIGEST_COLLISION before b'stale' exists_after False
stale_symlink_other_preserved True True b'target'
stale_wrong_mode_preserved True 0o640
forced_inner_objectdir_close ContractError:PUBLISH_OBJECT_ORPHANED hits 1 fd_delta 7 ref_exists False
forced_stale_fstat success 20 hit 1 fd_delta 1 stale_exists True
actual_refdir_fsync_fault REF_DURABILITY_UNCERTAIN hit 1 resolves_intended True replay 20
one_byte_ref_write_exact True
different_ref_same_object 64 [] 1 dangling 0 temps 0
publish_lock_contract contention REF_BUSY symlink OUT_REF_CONTRACT ref_still_resolves True
git diff --check: exit 0; stdout/stderr empty
```

The committed R2 additions cover the easy invalid pair, corrupt-old-ref priority, ordinary exact-name stale cleanup, other-ref preservation, and one outer close failure. They omit all three failing probes above.

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 0 Blocker / 2 Important / 1 Minor.
- Worst Standards issue: none.
- Worst Spec issue: stale-temp recovery currently violates the deterministic `DIGEST_CHECK` zero-change contract by deleting temp state before returning `DIGEST_COLLISION`.
