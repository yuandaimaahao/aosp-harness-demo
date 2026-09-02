# Task 3.1 fresh independent CLI/recovery security review R1

- Range: `6953c19e73a5edc500fcc2f26a1ef94474b9a1cf..fa278b4d98594067a2d4cb6f6425a1de488a2e9f`
- Immutable package: `review-6953c19e-fa278b4d.md`
- Commit: `fa278b4 feat(harness): add seed verification cli`
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**
- Findings: **1 Blocker / 0 Important / 2 Minor**

## Standards — PASS

The strict range changes only the five task-owned files. Modes are correct: dispatcher, direct command, and shell acceptance entry are `100755`; the marker is a regular `100644` file with exact bytes `seed-contract-runtime/v1\n`. `git diff --numstat` is 77 additions and one deletion, so both net additions (`76`) and total changed lines (`78`) are within the task ceiling of 80. `git diff --check` is clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found; parity, the shared harness regression, and the public demo verifier all pass. The compact one-line test style is already established in the touched driver, so it is not raised as a new Fowler smell.

## Spec — FAIL

### B1 — the wrapper verifies one module path but can import a preloaded module instead

`common/.harness/closure/v1/commands.d/verify-seed:8-14` applies `lstat` to the intended source leaf, then performs a normal name import after `sys.path.insert`. Python consults `sys.modules` before that path. Startup customization can therefore preload an unrelated module that supplies the nine named exports and the expected ABI string; the checked `common/.harness/closure/v1/lib/seed_contract_runtime.py` is never executed. In an exact-head probe, a `sitecustomize.py` supplied through `PYTHONPATH` inserted such a module, and:

```text
PYTHONPATH=<poison> common/.harness/closure/v1/commands.d/verify-seed /definitely/not/a/seed.json
exit 0
stdout: SEED ABI PASS
stderr: empty
```

Without the preload, the same nonexistent positional input cannot pass. This defeats R10 verification, R12 fail-closed channels, and R14's requirement to import the exports from the checked exact module. It also leaves the `lstat`→`read_bytes` and `lstat`→import pathname windows vulnerable to replacement. Implement the design's fd-based loader: open marker and module with no-follow semantics, verify the opened regular inodes, read exact bytes from those fds, and compile/execute the verified module bytes in a private namespace rather than consulting `sys.modules`. Add the poison/preload case as an exact CLI regression.

### M1 — the committed CLI case does not establish the mandatory grammar/preamble/parity matrix

`common/tests/test_seed_contract_runtime.py:181-206` passes, but it tests only one marker failure (missing marker), four malformed argv examples, and output-channel parity. It does not cover marker wrong bytes/symlink/non-regular, module missing/symlink/non-regular/import failure/missing export, dispatcher missing-subcommand and non-regular-target edges, or the full unknown/missing/repeated/reordered/extra option matrix for both productions. It also does not snapshot and compare canonical object/ref bytes, artifact/nested digests, or predicate results across dispatcher/direct execution as R13 and the acceptance checklist require. Consequently B1 remains green and `PASS cli` is materially weaker than the task's stated matrix.

### M2 — the required pre-implementation red evidence is absent

The task requires `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/evidence/task-3.1-red.txt` containing the exact failing command/exit/stdout/stderr from before dispatcher/direct/marker implementation. The immutable package does not carry that evidence, and the specified live evidence path is absent. This is a process/evidence defect rather than a runtime defect, but task acceptance is incomplete until the required immutable red record is present.

## Confirmed behavior

- Dispatcher missing-subcommand, invalid-name, unavailable target, direct grammar errors, and tested mixed-fault ordering map to exit 30 with empty stdout and one exact `CONTRACT CODE` stderr line.
- The dispatcher derives its command directory from its own realpath and rejects missing, leaf-symlink, non-regular, and non-executable targets in the reviewed implementation; the committed case directly covers missing, leaf-symlink, and non-executable files.
- The direct wrapper performs its marker/module/export/ABI preamble before grammar, imports all nine required stable exports, derives state from `STORE.parent.parent`, and passes the harness repo realpath as its verifier forbidden root.
- The two exact productions accept the fixture and local ref examples; malformed, repeated, reordered, missing, or extra shapes fall through to `ARGUMENT_ERROR` in source inspection. Public-real failure is translated exactly, and the binding `TypeError` seam returns `RUNTIME_INTERNAL` without traceback.
- Exact success channels are correct for the covered positional, local-ref, and dispatcher/direct cases. No AOSP path, envsetup, lunch, build, sync, download, package, flash, or network operation appears in the strict range or was run during review.

## Executable evidence

All implementation checks ran from isolated archive `/tmp/aosp-cli-review.WTWnY5` at exact head `fa278b4d98594067a2d4cb6f6425a1de488a2e9f`; the dirty live checkout was not used for behavioral tests and no real AOSP tree was inspected.

```text
bash common/tests/test-seed-contract-runtime.sh --case cli
RESULT PASS seed-contract-runtime
exit 0; stderr empty

python3 common/tests/test_seed_contract_runtime.py canonical-core evidence-schema seed-schema terminal-golden state-paths store-object ref-resolve ref-publish cli
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

bash common/tests/test-harness.sh
final: RESULT PASS  shared Harness regression suite
exit 0; stderr empty

bash common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约
exit 0; stderr empty

bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
final: RESULT PASS
exit 0; stderr empty

git diff --check 6953c19e73a5edc500fcc2f26a1ef94474b9a1cf..fa278b4d98594067a2d4cb6f6425a1de488a2e9f
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 1 Blocker / 0 Important / 2 Minor.
- Worst Standards issue: none.
- Worst Spec issue: the runtime availability preamble can be bypassed with a preloaded module, allowing invalid input to report exact success.
