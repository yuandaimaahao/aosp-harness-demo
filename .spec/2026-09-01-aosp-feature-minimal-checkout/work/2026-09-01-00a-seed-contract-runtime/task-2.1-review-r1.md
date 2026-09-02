# Task 2.1 fresh independent security review R1

- Range: `b0d0b133da3a161aa2fde448033f7b737f8881be..3c3efcb2a9d9e15aa2e8d5a69bb97a46b25efaed`
- Immutable package: `review-b0d0b133-3c3efcb2.md`
- Commit: `3c3efcb feat(harness): confine runtime state paths`
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**
- Findings: **2 Blocker / 1 Important / 2 Minor**

## Standards — PASS

The exact range changes only the two task-owned files. `git diff --numstat` is runtime `36/1` and test `16/1`: 52 additions (54 changed lines including deletions), within the task ceiling (`52 <= 65`, and also `54 <= 65` if churn is counted). `git diff --check` is clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found, and the range introduces no review-worthy Fowler smell beyond the established compact style.

## Spec — FAIL

### B1 — a non-regular `out_ref` FIFO hangs instead of failing deterministically

Runtime line 55 opens the untrusted leaf with blocking `O_RDONLY|O_NOFOLLOW` before checking `fstat`. Opening a FIFO with no writer blocks indefinitely, so an existing non-regular ref can deny service instead of producing `ContractError("OUT_REF_CONTRACT")`. This violates R5's existing-ref regular-file rule and R12's deterministic error contract. An exact-head multiprocessing probe remained alive after one second and had to be terminated (`fifo_ref HANG>1s`). The leaf must be classified without a blocking open (for example with a no-follow metadata/path fd), with the regular read opened only after type validation.

### B2 — an intermediate rename can redirect directory creation outside the declared state path

`_open_dirs` lines 30–34 advances to a child fd and discards the parent, but never proves that the opened directory remains at the lexical path used for the returned mapping. In an exact-head scheduled-race probe, `state/artifacts` was renamed after its no-follow open and before the next component. `validate_state_paths` returned success and claimed `state/artifacts/v1/sha256`, that declared directory did not exist, and the implementation created `outside/moved-artifacts/v1/sha256`. Thus `openat`/`O_NOFOLLOW` prevents symlink following but does not make the multi-component creation race-safe; R5/R6 confinement and the outside-entry invariant are not met under a rename race.

### I1 — invalid `forbidden_roots` elements get the wrong staged error

Line 39 validates only that the container is a tuple. Lines 44–47 let invalid elements reach `os.path.realpath` and translate `TypeError` to `STATE_DIR_CONTRACT`. Exact-head probes for `(123,)` and `(b"/tmp",)` both returned `STATE_DIR_CONTRACT`. The stable API and design require successfully bound value/type errors to be `ARGUMENT_ERROR`, ahead of filesystem/path validation. Validate every tuple element before the state-path stage; malformed/relative/non-realpath roots should also not acquire cwd-dependent meaning silently.

### M1 — directory walking imposes an undocumented read-permission requirement

Lines 27 and 30 use `O_RDONLY|O_DIRECTORY` for every component. A state directory with mode `0300` is writable and searchable (`os.access(..., W_OK|X_OK) == True`) but not readable; the exact-head probe returned `STATE_DIR_CONTRACT`. R5 requires an existing writable directory, not a listable/readable one. Use a traversal fd mode that requires search permission rather than directory read permission, while retaining no-follow and directory checks.

### M2 — the task test misses the security and error-priority edges above

Test lines 96–110 cover the nominal mapping, mutation rejection, a top-level state symlink, one parent symlink, basic escape, equal/root containment, and one chmod case. They do not cover an existing FIFO or other blocking non-regular leaf, intermediate component rename, invalid tuple elements and exact code, execute/write-only valid directories, valid `out_ref=None`, existing regular/non-regular ref leaves, store-component symlinks, prefix-sibling containment, or missing lexical leaves under a forbidden root. Consequently `PASS state-paths` does not establish the required R5/R6/R12 matrix.

## Confirmed behavior

- `validate_state_paths` is keyword-only; positional, missing-keyword, and unknown-keyword calls raise native `TypeError`.
- The returned `MappingProxyType` has the six exact keys, rejects mutation, derives `artifact_store`, `object_dir`, `ref_parent`, and `lock_path` exactly, and returns null for the final three values when `out_ref` is absent.
- Independent basic probes confirmed rejection of relative/missing state, wrong store, whole-path/store/ref-parent symlinks, directory ref leaves, lexical escape, equal/ancestor/store forbidden roots, and a missing out-ref leaf under a forbidden root. A prefix sibling is not misclassified.
- The red asset records the required pre-implementation missing-API failure. The strict range contains no AOSP, network, sync, build, envsetup, lunch, package, flash, or download operation.

## Executable evidence

All executable checks ran in detached exact-head worktree `/tmp/aosp-harness-2.1-review-r1.2Joj3j/tree` at `3c3efcb2a9d9e15aa2e8d5a69bb97a46b25efaed`. No real AOSP path was inspected.

```text
python3 common/tests/test_seed_contract_runtime.py state-paths
PASS state-paths

python3 common/tests/test_seed_contract_runtime.py canonical-core concurrent-core evidence-schema seed-schema terminal-golden state-paths
PASS canonical-core
PASS concurrent-core
PASS evidence-schema
PASS seed-schema
PASS terminal-golden
PASS state-paths

independent basic path/call-shape probe
PASS independent-basic-path-matrix
PASS keyword-only-missing-unknown-call-shape

independent edge probes
fifo_ref HANG>1s
rename race: returned success; declared_object_dir_exists=False; outside_created=True
write-exec-only: W_OK|X_OK=True, R_OK=False; STATE_DIR_CONTRACT
forbidden_roots (123,): STATE_DIR_CONTRACT
forbidden_roots (b'/tmp',): STATE_DIR_CONTRACT

bash common/tests/test-harness.sh
RESULT PASS  shared Harness regression suite

bash common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约

bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
final: RESULT PASS

git diff --check b0d0b133da3a161aa2fde448033f7b737f8881be..3c3efcb2a9d9e15aa2e8d5a69bb97a46b25efaed
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 2 Blocker / 1 Important / 2 Minor.
- Worst Standards issue: none.
- Worst Spec issues: blocking FIFO leaves violate deterministic failure, and intermediate rename races break path confinement.
