# 03a1 Task 4 implementation diff review

Reviewer: `review_design_03a_r1`

Verdict: **PASS** — blocker 0 / important 0 / minor 0

## Scope

- Implementation worktree: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a1-session-path-race-assurance`
- TASK_BASE: `e5f4f76f1a44d2fdc757ebb6f7391a9f08887fb0`
- TASK_HEAD: `f72aaefddd4fa6e06c6c156ff1f3df58b5f27ca9`
- Commit: `f72aaef test(session): complete race family matrix`
- Task diff: exact modification of `tests/lib/session-path-race-driver.py`, `98 + / 14 -`
- Sources checked: current requirements/design/tasks Task 4, `task-4-brief.md`, `task-4-red.log`, `task-4-report.md`, and the complete BASE..HEAD diff.

BASE is the merge-base of BASE and HEAD; the task diff contains one non-empty commit. The implementation worktree was clean before and after review. No implementation or spec file was modified.

## Standards

**PASS — 0 findings.**

The change extends the existing single executor, inventory/delta oracle and single-anchor injection flow rather than introducing a second matrix engine. The compact expressions are consistent with the validated 400-line private-driver blueprint and remain mechanically testable. The commit is a normal personal-project Conventional Commit. No actionable duplication, speculative abstraction, hidden public surface or unrelated refactor was found.

## Spec

**PASS — 0 findings.**

### Deterministic red and Task 4 boundary

- The BASE driver was independently executed from its Git blob with the fixed 37-row TSV. It executed the first 21 primary cases, then failed on `mkdir-replace-root` with rc1, stdout 0B, CASE_LOG 0B, 21 hook files and exact tail `AssertionError: matrix executor incomplete`; production provider SHA remained unchanged.
- HEAD adds only the five managed lifecycle families, `default_rows()` and the self-test order/hash gate. Static inspection finds exactly one `self-disproof incomplete` occurrence and no `must_reject`, `reject_field`, self-disproof list or named 14-oracle harness. Task 5 has not been implemented early.

### Five managed families across three layers

- The external 37-row run exercised all five families at root/project/session. All 15 managed cases had one exact MANAGED hook with the specified fields: mkdir replacement `before_open/1/0`; mkdir failure `before_mkdir/0/0`; post-mkdir disappearance `before_open/1/0`; open disappearance and final-stat disappearance `before_open/0/0`.
- Child protocol assertions require mkdir replacement to be unsafe/rc2 and the other four families to be operation/rc1, with exact empty stdout and exact stderr. The complete run returned the private outer success summary only after all child stream/hook/delta checks passed.
- Representative one-row runs for all five families and the reverse two-row `real-eio,swap-root-safe-dir` run each returned rc0, exact 38B stdout, empty stderr and a CASE_LOG containing only the input IDs in input order.

### Runtime original and object deltas

- Before replacing a freshly made target, the injected hook records directory type, device, inode, numeric mode and uid from a no-follow stat. The oracle derives its exact expected hook fields from the post-run `.old` signature. Runtime inspection at all three layers confirmed the hook tuple equals `.old`, `.old` remains EUID/0700, replacement is EUID/0755 and has a different inode.
- Replacement delta permits exactly the newly added target and `target.old`; the target/old predicates and protected signatures reject any other addition or mutation. Both open/final-stat disappearance permit exactly removal of the target. Makedir failure and post-mkdir disappearance require zero delta. Runtime inspection confirmed the target/old presence or absence for all 15 cases and no later-layer creation.
- Five isolated source-copy mutants were rejected rc1/no PASS/log0: wrong catch, wrong made, changed runtime-original mode before rename completion, an unexpected object in a zero-delta case, and an unexpected object in a removal-delta case. A separate wrong-phase mutant was likewise rejected by the ordered-hook oracle. This gives active failure evidence for phase/made/catch, runtime-original binding and all three Task 4 delta classes.

### Fixed matrix, publication and self-test red seam

- The external matrix returned rc0, stdout exactly `RESULT PASS  session path race driver\n` (38B), stderr 0B and CASE_LOG exactly equal to the 37 ordered input IDs. The nine family counts were `9/3/9/3/3/3/3/3/1`; ordered log SHA-256 was exactly `721b3687bda848db7b6481c527f491e6733cf376dbade3dd37b319fce8029bc8`.
- The run created 37 hook files with 46 total hook lines: one per non-EEXIST case and two ordered hooks per EEXIST case. Production provider SHA remained `07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`.
- The provider byte check precedes the held-fd CASE_LOG write. An isolated final-provider mutation after a genuine EIO case was rejected rc1/no PASS with an existing but 0B CASE_LOG.
- Direct self-test returned rc1, stdout 0B, no PASS and exact final diagnostic `AssertionError: self-disproof incomplete`. Independent `strace -f -yy` recorded exactly 46 writes to `*.hook` and one 780-byte write to `cases.log` containing all 37 ordered IDs before the red seam. The source then checks the exact executed list, provider bytes, log contents, row count and fixed hash before reaching the sole red assertion.

### Compatibility, exact size and regressions

- Python 3.8 AST grammar and compile passed. Available Python 3.9.25 independently passed protocol (rc0/28B/0B), compile and the expected self-test red seam. No Python feature newer than 3.8 was introduced.
- Physical driver size is exactly 400 lines. From execution BASE `c959efaf9887808621852aff28073cf1f8789ca7` through HEAD, the exact and only path is `tests/lib/session-path-race-driver.py` at `400 + / 0 -`; Task 4 itself is `98 + / 14 -`.
- Execution BASE..HEAD has zero diff in foundation, 03a provider and their tests. Each of the three production anchors occurs exactly once. `tests/test-session-state-foundation.sh` and `tests/test-session-path.sh` both pass.
- `git diff --check TASK_BASE..TASK_HEAD` passes and final implementation `git status --porcelain` is empty.

## Active evidence rerun

- BASE 37-row deterministic red fixture
- HEAD full 37-row matrix, five representative 1-row subsets and reverse 2-row subset
- complete managed hook/object inspection for five families at all three layers
- six isolated managed-oracle mutants plus one provider-before-log mutant
- direct and `strace` self-test red-seam verification
- Python 3.8 grammar, Python 3.9 runtime, exact1/400, zero-diff, upstream regression and clean gates

Result: all Task 4 gates passed; Task 5 may proceed after controller records this review in the manifest/ledger.
