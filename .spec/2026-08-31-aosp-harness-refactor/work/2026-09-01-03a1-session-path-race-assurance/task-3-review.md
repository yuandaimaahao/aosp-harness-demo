# 03a1 Task 3 implementation diff review

Reviewer: `review_design_03a_r1`

Verdict: **PASS** — blocker 0 / important 0 / minor 0

## Scope

- Implementation worktree: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a1-session-path-race-assurance`
- TASK_BASE: `565008482663664d9192817ccff9810993ca8ba0`
- TASK_HEAD: `e5f4f76f1a44d2fdc757ebb6f7391a9f08887fb0`
- Commit: `e5f4f76 test(session): cover primary path races`
- Task diff: exact modification of `tests/lib/session-path-race-driver.py`, `152 + / 19 -`
- Sources checked: current requirements/design/tasks Task 3, `task-3-brief.md`, `task-3-red.log`, `task-3-report.md`, and the complete BASE..HEAD diff.

BASE is the merge-base of BASE and HEAD; the task diff contains one non-empty commit. The implementation worktree was clean before and after review. No implementation or spec file was modified.

## Standards

**PASS — 0 findings.**

No root coding-standard document applies beyond the repository README; scoped `common/` and `codex/` AGENTS files do not govern `tests/lib/`. The new setup/exercise/delta helpers remove rather than duplicate the common family flow and match the validated round7 structure. The denser expressions are consistent with the hard 400-line blueprint and remain locally testable. No actionable duplication, divergent responsibility, speculative abstraction or other baseline smell was found.

## Spec

**PASS — 0 findings.**

### Red phase and dispatcher boundary

- The BASE driver was independently executed from its Git blob. The ordered 22-row matrix failed deterministically on the first swap with rc1/stdout0/log0/hook0; the reverse `real-eio, swap-root-safe-dir` input executed one genuine EIO hook and then failed rc1 with log0. Provider bytes remained unchanged. This matches the recorded red evidence without relying on a fabricated source.
- HEAD dispatches only swap, wrong-EUID, EEXIST and retained real-EIO. The five managed lifecycle families still hit `matrix executor incomplete`; `self-test` remains rc1/no PASS.

### Single-anchor and shared execution contract

- Each case calls `injected_copy` once with exactly one selected anchor. The function first requires all three production markers exactly once, locates one marker-bearing line, performs one strict line replacement, compares the complete copy against that exact replacement and rechecks all three marker counts.
- All 22 successful child copies were inspected: each differs from production provider bytes while retaining exactly one occurrence of all three markers. Hook files are one per case; total lines are exactly 31: MANAGED 27, EXPECTED_EUID 3 and OS_ERROR 1.
- Missing and duplicate fixtures for each of MANAGED, EXPECTED_EUID and OS_ERROR were independently run: 6/6 failed rc1 before a hook, with CASE_LOG 0B and isolated provider unchanged.
- All families use the same `exercise`, independent stream capture, inventory/signature/delta assertion, executed-ID list and final held-fd case-log path. There is no second executor or path-based CASE_LOG write.

### Swap 9

- All root/project/session × safe-dir/link/file cases produced exact MANAGED `before_open/0/0`, unsafe rc2/empty stdout/exact stderr and no later-layer object.
- `swap_delta` selects `target/**`, rekeys every path by the identical relative suffix to `target.old/**`, removes only old descendant keys, treats `target` as the sole changed key and preserves every other signature.
- Runtime fixtures confirmed that `.old` retained the original directory identity and its `victim` retained sentinel content; replacement inode differed from the old target. Safe-dir was EUID/0700, link `readlink` was exactly `.old`, and file was EUID/0600 with the empty-file SHA-256.
- Four isolated mutants—changed victim mode, unsafe safe-dir mode, wrong symlink target and nonempty file content—were each rejected rc1/no PASS with CASE_LOG 0B. This actively proves the subtree and mode/readlink/hash predicates can fail.

### Wrong-EUID 3

- Root/project/session cases produced exact `EXPECTED_EUID|layer|name|N/A|0|0` and unsafe streams.
- Each final scoped fixture contained exactly the pre-existing chain plus provider copy: no later layer and no added/removed/changed path. An isolated hook mutant that added an unexpected sibling was rejected rc1/log0, demonstrating the zero-delta oracle is active rather than inferred only from the stream.

### EEXIST 9

- Every safe/unsafe/disappear case at all three layers produced the exact ordered two hooks `before_mkdir/0/0` then `after_eexist/0/1`.
- Safe cases returned the exact physical session path and added only the required EUID/0700 directory suffix. Unsafe cases returned exact unsafe streams, preserved a type-dir EUID/0755 winner and created no later layer. Disappear cases returned exact operation streams and left the target absent with zero delta.
- Four isolated mutants—missing second hook, an extra safe child, a 0700 unsafe winner and an unexpected sibling after disappearance—were all rejected rc1/no PASS with log0. Thus hook order and all three delta classifications have independent failure evidence.

### Ordering, inventory and publication

- The ordered 22-row matrix returned rc0, stdout exactly 38B, stderr 0B and CASE_LOG exactly equal to the 22 input IDs; family counts were 9/3/9/1.
- Reverse `real-eio, swap-root-safe-dir` and eight representative one-row subsets returned success with only their input IDs and hooks, proving no hidden full-matrix dependency.
- The actual `inventory()` functions were extracted without alteration and run on reverse-created `z-last/m-middle/a-first` plus nested `z-child/a-child`; dict key order equaled sorting by `os.fsencode(relative_path)`, proving filesystem-byte canonical order.
- `executed == expected_ids` is checked before publication. Final production provider bytes are checked at source line 311, before the first held-fd log write at line 312. An isolated provider that self-mutated after a genuine EIO hook was rejected rc1/hook1/log0/no PASS; tracked provider bytes remained unchanged.

### Scope, compatibility and regressions

- All 15 legal managed lifecycle rows were run separately: each returned rc1/stdout0/no PASS, CASE_LOG 0B and hook0. No mkdir-replacement/failure or disappearance implementation, built-in 37 rows, self-disproof, public API, capability marker or 03a2 entrypoint was added.
- Python 3.8 AST grammar and in-memory compile passed. Protocol remained rc0/28B/0B; misuse remained rc2; correct self-test shape remained the explicit rc1 seam.
- Task BASE..HEAD is exactly one driver with task numstat 171. Execution BASE `c959efa..` through HEAD is exact one driver at `316 + / 0 -`, within 400.
- Task diff-check, execution-scope checks and 03/foundation + 03a provider/tests zero-diff passed. `tests/test-session-state-foundation.sh` and `tests/test-session-path.sh` both passed. Commit message is the required personal Conventional Commit; final worktree status is clean.

## Active evidence rerun

- BASE red 22-row and reverse partial-execution fixtures
- HEAD 22-row full matrix, reverse2 and eight one-row representatives
- complete post-run object/hook/copy inspection for all 22 cases
- nine behavior/oracle mutants and six marker missing/duplicate fixtures
- extracted inventory reverse-creation oracle
- fifteen lifecycle red rows and provider-before-log mutation fixture
- Python 3.8 grammar, upstream regressions, exact1/400, zero-diff and clean gates

Result: all Task 3 gates passed; Task 4 may proceed after controller records this review in the manifest/ledger.
