# 03a1 Task 5 and cumulative implementation review

Reviewer: `review_design_03a_r1`

Verdict: **PASS** — blocker 0 / important 0 / minor 0

## Scope

- Implementation worktree: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a1-session-path-race-assurance`
- TASK_BASE: `f72aaefddd4fa6e06c6c156ff1f3df58b5f27ca9`
- TASK_HEAD: `1c6e14f0e8d74b223956f605d41d719b6c9fc5c6`
- Execution BASE: `c959efaf9887808621852aff28073cf1f8789ca7`
- Commit: `1c6e14f test(session): close race driver assurance`
- Task diff: exact modification of `tests/lib/session-path-race-driver.py`, `57 + / 57 -`
- Sources checked: current requirements/design/tasks Task 5, `task-5-brief.md`, `task-5-red.log`, `task-5-report.md`, prior task reviews and the complete Task and execution-BASE diffs.

TASK_BASE is the merge-base of BASE and HEAD and the task diff is one non-empty commit. The implementation worktree was clean before and after review. No implementation or spec file was modified.

## Standards

**PASS — 0 findings.**

No scoped repository coding standard governs `tests/lib/`; the root README adds no formatting convention. Task 5 reuses the existing executor and real oracle callbacks, removes only blank-line space and does not introduce a second test framework. The compact layout is the reviewed 400-line constraint rather than unrelated minification. No actionable duplication, speculative abstraction, hidden public API, divergent responsibility or scope creep was found. The commit follows the requested personal-project Conventional Commit form.

## Spec

**PASS — 0 findings.**

### Red phase and Task 5 diff

- The TASK_BASE driver was independently loaded from its Git blob and run with the tracked foundation/provider. It returned rc1, stdout 0B, no PASS and exact final diagnostic `AssertionError: self-disproof incomplete`, matching the recorded deterministic red seam after Task 4.
- Task 5 deletes that one red assertion and adds only probe capture, `must_reject`, 14 self-test callbacks and the final ordered-name gate. The R1–R6 path/log, stream, injection, signature, inventory, delta, runtime-original and provider-before-log checks remain present. No production/provider/test-shell file changed.

### Fourteen active self-disproofs

- The main self-test returned rc0, stdout exactly `RESULT PASS  session path race driver\n` (38B) and stderr 0B.
- Instrumenting only `must_reject` in a temporary driver copy exposed 14 real `AssertionError` results in the exact R7 order: protected-signature/protected-signatures, unexpected-inventory/paths-added, allowed-changed-paths/changed-paths, symlink-target/predicate, file-hash/predicate, mode/predicate, inode/predicate, EEXIST-second-hook/ordered-hooks, marker-count/source-anchor-counts, sentinel/ordered-hooks, phase/ordered-hooks, made/ordered-hooks, catch/ordered-hooks and case-invocation. Each callback mutates the corresponding real Task 3/4 probe rather than a common fake callback.
- `must_reject` catches only `AssertionError`, records the supplied exact label and fails when the callback accepts the mutation. An isolated callback changed to raise `ValueError` propagated that unknown exception; it was not counted as a rejection. Swapping the first two expected labels failed at exact `self-disproof execution`, proving the final name/order comparison is active.
- The tasks-prescribed 14-copy harness found exactly one `must_reject` or `reject_field` call site for every R7 label. Replacing each site in turn with `must_reject(lambda: None, label)` produced 14/14 rc1, stdout 0B and no PASS. Driver and provider hashes remained unchanged.

### Self-test-only boundary and matrix regressions

- Protocol returned exact rc0/28B/0B without reading dependencies. Six representative unknown-mode, missing-arity and extra-argument shapes returned rc2, stdout 0B and no PASS.
- Legal 1-row, reverse 2-row (`real-eio`, then `swap-root-safe-dir`) and fixed 37-row `run-matrix` calls all returned rc0/38B/0B. Each CASE_LOG contained only the input IDs in input order; the complete log SHA-256 was exactly `721b3687bda848db7b6481c527f491e6733cf376dbade3dd37b319fce8029bc8`.
- A temporary driver whose `must_reject` immediately raises still passed a one-row `run-matrix`, proving the active self-disproof branch is not entered by the external CLI. The production source has no 03a2 entrypoint or external matrix generator.

### Path, log and publication ordering

- Ten direct fixtures—relative workspace, relative log, missing parent, symlink parent, existing workspace, symlink workspace, non-direct log, workspace `..`, log `..` and provider-direct workspace—were rejected rc1/no PASS before case publication. The intended absolute raw-`.` alias passed rc0/38B/0B.
- Three isolated post-mkdir race fixtures placed an existing file, symlink or hardlink at CASE_LOG before its open. All were rejected by the `O_EXCL|O_NOFOLLOW` held-directory-fd path with rc1/no PASS and unchanged tracked provider.
- An isolated provider mutation after a genuine EIO case but before the final provider gate returned rc1/no PASS with CASE_LOG present at 0B. This actively confirms the provider byte check precedes the sole held-fd log write.

### Cumulative R1–R9 delivery

- The fixed self-test remains self-contained: 37 cases in the required `9/3/9/3/3/3/3/3/1` family order, the same shared executor as external rows, unique single-anchor child copies, exact streams/hooks, complete signature/inventory/delta checks and the fixed ordered-ID hash. The already accepted Task 1–4 reviews plus the Task 5 reruns cover all R1–R7 behavior without weakening earlier oracles.
- Python 3.8 AST grammar and in-memory compile passed. Available Python 3.9.25 compiled the file and ran self-test at exact rc0/38B/0B.
- Current-worktree `tests/test-session-state-foundation.sh`, `tests/test-session-path.sh` and `bash ./scripts/check.sh --offline` all passed. Offline output did not invoke or publish the private driver summary.
- A fresh full-history file-URL clone at candidate HEAD contained 118 commits; a true `git clone --depth 1 file://...` checkout contained exactly one. Both independently passed protocol at 0/28B/0B, self-test at 0/38B/0B and offline at rc0, and both remained clean. The driver contains no Git/history query, fixed commit SHA, 03a2 path or future shell entrypoint.
- Execution BASE..HEAD is exact one added file, `tests/lib/session-path-race-driver.py`, at `400 + / 0 -`; physical size is exactly 400 lines. Foundation, 03a provider and their tests have zero execution-range diff. Driver SHA is `cb8277c52bc6dd1591c78c58a0baee8fe1a0d7d17305380f0f79f5d745fd94c0`; provider SHA remains `07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`.
- Task diff-check and final clean-status gates pass. The controller manifest currently contains the four already reviewed contiguous PASS rows through TASK_BASE; the Task 5 row and ledger entry are intentionally pending this independent PASS. No 03a2 spec/work directory, worktree, branch, base or dispatch asset exists.

## Active evidence rerun

- TASK_BASE deterministic self-test red
- candidate main self-test and instrumented 14-callback exception trace
- tasks-exact 14-copy mutation harness, unknown-exception and order mutants
- protocol plus six misuse shapes; legal 1/2/37-row matrices and self-test-leak poison
- ten path fixtures, three log-race fixtures and provider-before-log mutation
- Python 3.8 grammar, Python 3.9 runtime, foundation/path/offline regressions
- fresh full-history and true file-URL depth-1 protocol/self-test/offline checkouts
- exact1/400, physical 400, upstream zero-diff, provider hash, diff-check, clean and 03a2-absence gates

Result: Task 5 and the cumulative 03a1 private driver delivery pass independent implementation review. The controller may append the fifth PASS manifest row and run the fail-closed ledger/order gate before starting 03a2.
