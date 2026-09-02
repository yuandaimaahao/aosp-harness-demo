# 03a1 Task 2 implementation diff review

Reviewer: `review_design_03a_r1`

Verdict: **PASS** — blocker 0 / important 0 / minor 0

## Scope

- Implementation worktree: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a1-session-path-race-assurance`
- TASK_BASE: `d79de6bb6b10bce9ffd4238b071656cf7089db88`
- TASK_HEAD: `565008482663664d9192817ccff9810993ca8ba0`
- Commit: `5650084 test(session): isolate external race matrices`
- Task diff: exact modification of `tests/lib/session-path-race-driver.py`, `170 + / 3 -`
- Sources checked: current requirements/design/tasks Task 2, `task-2-brief.md`, `task-2-red.log`, `task-2-report.md`, and the complete BASE..HEAD source diff.

BASE is the merge-base of BASE and HEAD; the diff is one non-empty commit. The implementation worktree was clean before and after review. No implementation or spec file was modified.

## Standards

**PASS — 0 findings.**

No root coding-standard document applies beyond the repository README; scoped `common/` and `codex/` AGENTS files do not govern `tests/lib/`. The change follows the validated round7 private-driver structure. The shared signature/inventory/delta helpers are required Task 2 output and are directly consumed by the EIO vertical slice, so they are not speculative generality. No actionable duplication, divergent responsibility or other baseline smell was found in this task diff.

## Spec

**PASS — 0 findings.**

### Matrix and path boundary

- TSV validation precedes workspace creation and case execution. It rejects NUL, empty input/field, wrong column count, duplicate IDs, unknown tokens, illegal family/layer/variant combinations and noncanonical IDs; all legal families are enumerated even though only EIO executes in this task.
- The path contract is the required round7 form: `parent.lstat()` plus absolute workspace, `parent.resolve(strict=True) == parent`, directory type, `lexists` leaf checks and direct-child log equality. No alternate ancestor walker was introduced.
- Workspace is created with `parents=False`, opened with `O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC`, fchmoded and fstat-verified as EUID/0700.
- CASE_LOG is opened relative to the held workspace fd with `O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC`, then fstat-verified as EUID/0600/link-count 1. Subsequent content I/O uses only held `log_fd` via `os.write`, `os.lseek` and `os.read`; no path-based log write/read exists.
- Raw absolute `.` aliases passed after Python `Path` lexical folding. Relative paths, retained `..`, missing parent, symlink parent, existing/symlink workspace and non-direct log paths all failed rc1 with no PASS and no case hook.

### EIO vertical slice and ordering

- The provider source must contain all three production markers exactly once. `injected_copy` locates and replaces only the unique OS_ERROR marker-bearing line, mechanically compares the copy with one exact source replacement, and rechecks all marker counts.
- A real injected `OSError(errno.EIO)` produced the exact hook `OS_ERROR|N/A|N/A|N/A|N/A|N/A`, child rc1/empty stdout/`error: session state operation failed\n`, zero scoped delta, and no state root.
- A valid one-row EIO matrix returned outer rc0, stdout exactly 38B, stderr 0B, CASE_LOG exactly `real-eio\n`, hook exactly one line, workspace/log modes exactly 0700/0600 and log link-count 1.
- The executed set is checked against input before log creation is committed. Production provider bytes are re-read and compared at source line 178, before the first held-fd log write at line 179.
- An additional deterministic ordering self-disproof used isolated foundation/provider fixtures whose child modified the isolated production provider after the EIO hook. Result: outer rc1, hook count 1, stdout 0B, no PASS and CASE_LOG 0B while the isolated provider mutation remained. The tracked provider hash stayed unchanged. This proves the final provider check gates log content rather than merely following it.

### Fail-closed and task boundary

- Independently rerun invalid-row matrix: 11/11 cases returned rc1/no PASS, workspace remained absent and case count was zero.
- Independently rerun invalid-path/capability matrix: 9/9 relative/dotdot/missing/symlink/existing/direct cases returned rc1/no PASS and zero case. Existing, symlink and hardlink log fixtures were also rejected unchanged; their isolated provider bytes remained unchanged.
- Every one of the 36 legal non-EIO rows was run separately: all returned rc1, stdout 0B, no PASS, CASE_LOG 0B and hook count zero. No swap, wrong-EUID, EEXIST or managed lifecycle behavior has been implemented.
- A mixed `real-eio` followed by an unimplemented swap row executed the EIO hook once but returned rc1/no PASS with CASE_LOG still 0B, proving partial execution cannot publish success.
- `self-test` remains the deterministic Task 3–5 red seam at rc1/no PASS. There is no built-in 37-row matrix, MANAGED/EXPECTED_EUID hook body, active self-disproof, runtime API, capability marker or future 03a2 entrypoint.

### Compatibility, scope and regressions

- Python 3.8 AST grammar parse and in-memory compile passed.
- Task BASE..HEAD name-only is exactly the driver; task numstat is 173 total. Execution BASE `c959efa..` through HEAD is exact one driver at `183 + / 0 -`, within 400.
- `git diff --check` passed. Execution-BASE..HEAD diff for foundation/provider and existing foundation/path tests is empty.
- `tests/test-session-state-foundation.sh`, `tests/test-session-path.sh`, and Task 1 protocol/misuse/self-test seam regressions all passed.
- Commit message is the specified personal-project Conventional Commit. Final worktree status is clean.

## Commands and active probes

- Git SHA/merge-base/log/name-status/numstat/diff-check and full source diff
- one-row EIO exact stream/hook/log/mode oracle
- raw-dot positive path case
- 36 legal-but-unimplemented single-row cases plus mixed partial-execution case
- 11 invalid TSV cases, 9 invalid path cases and 3 existing/symlink/hardlink log cases
- isolated provider-mutation ordering self-disproof
- Python 3.8 grammar/in-memory compile, 03/03a zero-diff and existing test regressions

Result: all Task 2 gates passed; Task 3 may proceed after controller records this review in the manifest/ledger.
