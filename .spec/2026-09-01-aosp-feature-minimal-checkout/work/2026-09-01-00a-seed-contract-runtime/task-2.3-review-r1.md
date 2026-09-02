# Task 2.3 fresh independent locked-resolver security review R1

- Range: `770fc1ff68bb01f1dd90e6ad6ec27ffd58e6737a..a5994969c1e6749e98af0c7f9fe7e797beb98f51`
- Immutable package: `review-770fc1ff-a5994969.md`
- Commit: `a599496 feat: add locked seed ref resolver`
- Authority: updated task 2.3 brief plus current `DECISIONS.md` stable-topology boundary
- Exact head under test: `a5994969c1e6749e98af0c7f9fe7e797beb98f51`
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**
- Findings: **2 Blocker / 3 Important / 1 Minor**

## Standards — PASS

The strict range changes only the two task-owned files. `git diff --numstat` is runtime `61/1` and test `19/1`: exactly 80 additions, satisfying the task ceiling (`80 <= 80`). `git diff --check` is clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found, and no separate Fowler smell is promoted beyond the repository's established compact runtime/test style.

## Spec — FAIL

### B1 — ref/object non-regular leaves can block the resolver indefinitely

Runtime lines 180–187 open every ref and object leaf with `O_RDONLY|O_NOFOLLOW` and inspect `fstat` only after the open. `O_NOFOLLOW` rejects a symlink but does not make FIFO/device opens nonblocking. An exact-head subprocess resolving a FIFO ref named `pass` exceeded a two-second timeout instead of returning the required post-lock `REF_CORRUPT`.

Static non-regular ref/object leaves are explicitly in the R5/R6 threat model, and R8/R12 require deterministic nonblocking resolution. Classify/open leaves without blocking (for example with `O_PATH|O_NOFOLLOW`, followed by an identity-safe nonblocking regular-file open) before reading bytes.

### B2 — unvalidated primary fields are used as `openat` pathnames outside the object store

Runtime lines 224–226 canonical-decode the primary object but do not validate its schema, kind, domain digest, or embedded digest syntax before passing `source_state.*_digest` and `guard.*_digest` to `_readat`. `_readat` accepts strings containing `/` and `..`; `O_NOFOLLOW` protects only the final component.

An exact-head probe placed a canonical, invalid seed at a valid 64-hex primary leaf. The resolver called `_readat` four times with `../../../sentinel` and returned `ARTIFACT_MISSING`. A crafted store can therefore make resolution read outside `ARTIFACT_STORE/sha256` (including forbidden roots) or combine this with B1 to block on an external FIFO. Validate the primary and require each evidence leaf to be exactly 64 lower hex before any evidence lookup, while retaining the specified missing/corrupt priority for safe names.

### I1 — the synthetic `.resolver-path-check` validates the wrong out-ref and reverses path priority

Runtime lines 202–203 reject actual-ref syntax before state validation and then call `validate_state_paths` on a fabricated sibling rather than `ref`. Exact-head probes showed:

- invalid state plus relative ref returned `OUT_REF_CONTRACT`, although the fixed pre-lock order requires `STATE_DIR_CONTRACT` before out-ref validation;
- `forbidden_roots=(ref,)` with `ref` an existing real directory passed confinement, created the adjacent lock, and reached post-lock `REF_CORRUPT` instead of pre-lock `OUT_REF_CONTRACT`;
- an actual FIFO ref named `.resolver-path-check` was observed before lock acquisition and returned `OUT_REF_CONTRACT` with no lock, rather than post-lock `REF_CORRUPT`.

Validate the real lexical out-ref for state containment/forbidden roots without observing its leaf, and perform state validation before out-ref contract classification.

### I2 — canonical schema-corrupt objects leak descriptor errors through the resolver ABI

Runtime line 229 invokes `_validate_artifact` inside the object loop, but lines 233–234 rethrow every `ContractError` unchanged. A canonical terminal object with an empty `failed_checks` list returned `DESCRIPTOR_SCHEMA_INVALID`; the ref resolver contract requires any existing object's bytes/kind/content/nested mismatch to be `REF_CORRUPT`.

Translate validator `ContractError` at the resolver boundary after preserving `ARTIFACT_MISSING` for genuinely absent safe leaves. This also ensures `PUBLIC_SCOPE_REQUIRED` remains strictly last.

### I3 — an unlock error skips directory-fd cleanup and escapes as raw `OSError`

Runtime lines 235–239 close the lock in an inner `finally`, but `_drop(nodes)` is a later statement. If `flock(LOCK_UN)` raises, execution skips `_drop(nodes)`. An exact-head injected unlock `EIO` escaped as raw `OSError` and left five directory fds open. Closing the lock still releases the kernel lock, but the stable API/finally contract and fd cleanup are violated. Nest cleanup so every exit closes all directory and lock fds without one cleanup error suppressing the rest.

### M1 — `ref-resolve` omits mandatory negative closure and priority coverage

Test lines 146–163 prove a nominal seed/terminal resolution, lock mode/owner, one held-lock contention case, several simple missing/symlink cases, and fixture-only public rejection. They do not exercise FIFO/nonblocking leaves, unsafe embedded digest paths, state-vs-ref priority, exact forbidden-root equality, canonical schema-corrupt objects, wrong object kind/domain/path digest, terminal null/non-null completed-kind closure, or negative project/count/sequence/journal/lunch relations. Consequently every implementation defect above remains green. Add table-driven independent mutations and mixed-fault assertions, including failure snapshots and fd deltas, while preserving the exact 80-addition ceiling or returning to PLAN.

## Confirmed behavior

- The callable is keyword-only with the specified arguments and returns the verified primary dict on nominal input.
- Existing lock leaves are opened with `O_NOFOLLOW`, required to be regular, exact effective-UID owned, and exact mode 0600; missing locks use adjacent `O_CREAT|O_EXCL|O_NOFOLLOW` then exact `fchmod(0600)`. Valid-fd contention is nonblocking and returns `REF_BUSY`.
- In ordinary execution, the lock is acquired before `_readat` observes the ref/object leaves and is held through closure/public validation. Nominal success had zero fd delta.
- Canonical ref bytes and `env_pass -> seed` / `terminal_report -> terminal_report` mapping are enforced. For safe 64-hex paths, object mode 0444, canonical bytes, expected kind/domain digest, and primary/evidence content digests are checked.
- Seed closure checks both source-state manifest digests/path sets/per-project digests, five trace counts, all journal exits, trace endpoint membership, and lunch exit. Terminal reports close each non-null completed digest to its matching kind. Public validation follows evidence closure.
- Existing tests' failure snapshots preserve object/ref/temp/sentinel bytes after the initial lock exists. The red evidence records the required missing-resolver failure. The strict range contains no AOSP access, envsetup, lunch, build, sync, fetch/clone, package, flash, or download operation.

## Executable evidence

All dynamic checks ran from detached exact-head worktree `/tmp/aosp-harness-review.gXcfA9`. No real AOSP path was inspected.

```text
python3 common/tests/test_seed_contract_runtime.py ref-resolve
PASS ref-resolve

python3 common/tests/test_seed_contract_runtime.py canonical-core concurrent-core evidence-schema seed-schema terminal-golden state-paths store-object ref-resolve
PASS canonical-core
PASS concurrent-core
PASS evidence-schema
PASS seed-schema
PASS terminal-golden
PASS state-paths
PASS store-object
PASS ref-resolve

independent exact-head probes
fifo-probe=blocked (2-second timeout)
unsafe nested names: ARTIFACT_MISSING; reads included '../../../sentinel' four times
invalid state + relative ref: OUT_REF_CONTRACT
forbidden_roots exact existing-directory ref: REF_CORRUPT; lock-exists=True
reserved basename FIFO: OUT_REF_CONTRACT; lock-exists=False
canonical invalid terminal primary: DESCRIPTOR_SCHEMA_INVALID
unlock fault: raw OSError [Errno 5]; fd_delta=5

bash common/tests/test-harness.sh
RESULT PASS  shared Harness regression suite
bash common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约
bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
RESULT PASS

git diff --check 770fc1ff68bb01f1dd90e6ad6ec27ffd58e6737a..a5994969c1e6749e98af0c7f9fe7e797beb98f51
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 2 Blocker / 3 Important / 1 Minor.
- Worst Standards issue: none.
- Worst Spec issues: non-regular leaves can hang resolution indefinitely, and unvalidated embedded digests escape the object-store pathname boundary before validation.
