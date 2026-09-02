# Task 3.1 fresh independent CLI/recovery security review R2

- Range: `6953c19e73a5edc500fcc2f26a1ef94474b9a1cf..8c55b7bc83183b69a01ed30bb54151e17b1516ad`
- Immutable package: `review-6953c19e-8c55b7bc.md`
- Commit: `8c55b7b feat(harness): add seed verification cli`
- Overall: **PASS** — Standards **PASS**, Spec **PASS**
- Findings: **0 Blocker / 0 Important / 1 Minor (non-blocking judgement call)**

## Blocker

None.

## Important

None.

## Minor

### M1 — terse names reduce local readability (Fowler Mysterious Name; judgement call)

`common/.harness/closure/v1/commands.d/verify-seed:6` names the fd-backed reader `take`, and `common/tests/test_seed_contract_runtime.py:183,188,193,207-208` uses compact names such as `r/c/o/e`, `a/one/two/q`, and `d/m/u/x/p/f`. Names such as `read_regular_bytes`, `result/exit_code/stdout/stderr`, and `direct/marker/module` would expose intent more directly. This is advisory only: the task's strict 80-addition ceiling and the established compact table-driven style make it non-blocking, and no documented repository standard is violated.

## Standards — PASS

The cumulative range changes exactly the five task-owned source files. `git diff --numstat` is 79 additions and one deletion, satisfying the task's additions ceiling of 80. Modes are dispatcher/direct/shell `100755`, marker `100644`, and the Python driver `100644`; marker bytes are exactly `seed-contract-runtime/v1\n`. `git diff --check`, Bash syntax, and Python syntax are clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found, and the required parity/public verifier regressions pass.

## Spec — PASS

### R1 findings are closed

1. **Poison/preload bypass closed.** `verify-seed:6-14` opens marker and module with `O_NOFOLLOW|O_NONBLOCK`, verifies each opened fd with `fstat`/`S_ISREG`, reads exact bytes from that fd, and compiles/executes the verified module bytes in the private `seed_contract_runtime_private` namespace. It performs no name import of `seed_contract_runtime`, so a `PYTHONPATH` `sitecustomize` preload in `sys.modules` cannot substitute for the checked module. The committed regression at `test_seed_contract_runtime.py:207` preloads all nine fake exports and proves a nonexistent fixture still returns exit 30, empty stdout, and exact `CONTRACT DESCRIPTOR_NOT_FOUND\n`.
2. **CLI/preamble/parity matrix closed.** `test_seed_contract_runtime.py:185-208` covers positional and ref success, dispatcher/direct exact channels, missing/invalid dispatcher command, missing/symlink/non-executable/non-regular target, marker missing/wrong bytes/symlink/non-regular, module missing/symlink/non-regular/import failure/missing exports, unknown/missing/repeated/reordered/extra grammar, runtime-before-argv priority, binding `TypeError` without traceback, preload poison, local/public predicate results, state-tree byte snapshot, and seed content/identity digest snapshots.
3. **Red evidence closed.** The required live asset `specs/2026-09-01-00a-seed-contract-runtime/evidence/task-3.1-red.txt` exists and records the exact pre-implementation command, exit 127, empty stdout, and exact missing shell-entry stderr. The absent shell entry was one of the task's required dispatcher/direct/marker acceptance assets, so this is valid red evidence rather than a post-implementation synthetic failure.

### Full task 3.1 contract

- `feature-closure:4-12` enforces the staged dispatcher priority, exact ASCII command regex, self-realpath-relative command lookup, regular/non-symlink/executable target checks, and exec-only child handoff. Invalid child argv is not parsed before command availability.
- `verify-seed:11-28` performs runtime availability before grammar; accepts only the one-positional or exact ordered ref/store/optional-public productions; translates expected `ContractError.code` to exit 30/empty stdout/one exact stderr line; translates all other runtime exceptions to `RUNTIME_INTERNAL`; and emits only the specified success line.
- The direct wrapper has no dependency on the dispatcher. It derives state from `STORE.parent.parent`, supplies the harness repository realpath as the forbidden root, resolves refs through the stable runtime, and cannot claim the public suffix unless `require_public_real` succeeds.
- The committed mixed-fault cases establish dispatcher ordering of missing subcommand `ARGUMENT_ERROR`, invalid name `INVALID_COMMAND`, then unavailable target `COMMAND_UNAVAILABLE` before child argv; direct startup likewise makes `RUNTIME_UNAVAILABLE` precede argv `ARGUMENT_ERROR`. Fixture/ref success and failure channels match exactly between dispatcher and direct execution, while the ref tree/object/ref bytes remain unchanged.
- The strict range contains no AOSP execution, sync/download, fetch/clone, package/flash operation, or reference to `/home/zzh0838/Project/lk7k-a17/system`; only schema field strings such as `envsetup_lunch` occur.

## Executable evidence

All behavioral checks ran from an isolated `git archive` at exact head `8c55b7bc83183b69a01ed30bb54151e17b1516ad`; no AOSP command or real AOSP tree was used.

```text
PYTHONDONTWRITEBYTECODE=1 bash common/tests/test-seed-contract-runtime.sh --case cli
RESULT PASS seed-contract-runtime
exit 0; stderr empty

PYTHONDONTWRITEBYTECODE=1 python3 common/tests/test_seed_contract_runtime.py canonical-core evidence-schema seed-schema terminal-golden state-paths store-object ref-resolve ref-publish cli
PASS canonical-core
PASS evidence-schema
PASS seed-schema
PASS terminal-golden
PASS state-paths
PASS store-object
PASS ref-resolve
PASS ref-publish
PASS cli
exit 0; stderr empty

PYTHONDONTWRITEBYTECODE=1 bash common/tests/test-harness.sh
RESULT PASS  shared Harness regression suite
exit 0; stderr empty

PYTHONDONTWRITEBYTECODE=1 bash common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约
exit 0; stderr empty

PYTHONDONTWRITEBYTECODE=1 bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
final: RESULT PASS
exit 0; stderr empty

git diff --check 6953c19e73a5edc500fcc2f26a1ef94474b9a1cf..8c55b7bc83183b69a01ed30bb54151e17b1516ad
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, one non-blocking naming judgement call.
- Spec: **PASS**, no findings.
- R1 B1/M1/M2: all closed with committed runtime/tests or the required live red-evidence asset.
