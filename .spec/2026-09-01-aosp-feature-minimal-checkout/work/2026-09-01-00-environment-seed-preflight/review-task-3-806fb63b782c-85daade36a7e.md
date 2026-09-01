# Task 3 independent review

## Final verdict

**FAIL**

- blocker: **4**
- important: **2**
- minor: **0**

Review scope was limited exactly to `review-806fb63b-85daade3.md` and `task-3-report.md`. No implementation file, process file, additional diff, or AOSP command was read or run.

## Findings

### Blocker 1 — Ledger syntax is validated, but the required task reports and reviews are never required to exist

The task-entry regular expression fixes the report/review filenames and validates the SHA-shaped anchors (review package lines 43–45, 60–82), and `_structure` compares the review filename anchors to the actual commit chain (lines 95–102). However, `_ledger` discards both artifact paths and never checks either path on disk. Consequently, a syntactically correct ledger whose four task reports and/or four reviews are missing still passes this part of the acceptance gate.

The self-test demonstrates the bypass: it emits ledger strings referring to all report/review files (line 189), creates none of them, and expects `_ledger` plus `_structure` to succeed (lines 190–194). This conflicts directly with the required report/review existence gate.

Required correction: retain or deterministically derive every exact report/review path, resolve it beneath the intended process directory, and fail closed unless every required artifact exists as the intended file type. Keep the existing task SHA and 12-character review-anchor checks.

### Blocker 2 — The acceptance decision is not bound to the current `HEAD`

`run` checks only that the supplied base equals the manifest base (lines 142–147), then validates the object named by `args.merge_commit` (lines 148–150). `_structure` correctly proves that the named merge has exactly two parents `[frozen base, task 4 tip]` and that the four task commits form a single-parent chain starting at the base (lines 85–102). It never verifies that the repository's current `HEAD` is that merge.

Therefore an old, otherwise valid merge and matching ledger can still be accepted after the real branch has advanced to an unrelated or additional commit. The task-chain ancestry checks are good but do not establish the required base/current-head relationship.

Required correction: resolve `HEAD` fail-closed and require it to equal the requested/ledger merge SHA at acceptance time; retain the exact task chain and exact two-parent checks. This also makes the frozen-base-to-current-head anchor unambiguous.

### Blocker 3 — Dirty tracked and untracked files in the real checkout are invisible to the gate

The only path comparisons are commit-to-commit `git diff --name-only` calls (lines 92–100). The rollback runs from the named commit in a new detached worktree (lines 118–133). Nothing in `run`, `_structure`, or `_rollback` inspects the real checkout's index, tracked modifications, or untracked files.

As a result, dirty tracked files under `common/` or the owned paths, and untracked files in those areas, can coexist with a PASS: they are absent from commit diffs and are not copied into the detached rollback worktree. This violates the required tracked/untracked common/path fail-closed behavior.

Required correction: before acceptance, inspect both tracked/index state and untracked state in the real checkout with machine-readable Git output, explicitly cover `common/` and all manifest-owned paths, and reject malformed/unclassifiable output rather than treating it as clean.

### Blocker 4 — The cumulative 800-line budget is reported but not enforced by accept mode

The implementation contains no `numstat` query, no generated-path filtering for budget accounting, and no comparison with 800. The task report states that the cumulative total is currently 633 and that task 4 has only 167 lines remaining (task report line 21), but that is evidence recorded by the task, not an acceptance invariant.

Thus task 4 can exceed the remaining 167-line allowance and still pass `_structure` so long as it changes only its owned path. `validate_plan(root, manifest)` is called (review package line 147), but this review package supplies no evidence that it measures the frozen-base-to-final-tip diff, and the accept-mode self-test never exercises an over-budget case.

Required correction: compute the final cumulative, non-generated numstat from the frozen base to the accepted task tip/merge tree, reject any parse anomaly, and fail when the total exceeds 800. With the reported task-3 total, task 4 must remain at or below 167 additional counted lines.

### Important 1 — The self-test omits the acceptance gate's highest-risk negative cases

The negative cases cover a missing ledger, a non-merge object, rollback leftovers, and regression failure (review package lines 195–207). They do not cover missing report/review artifacts, a valid historical merge while `HEAD` differs, dirty tracked state, dirty untracked state, or an over-budget final chain. In fact, the nominal fixture succeeds without creating the artifact files, masking Blocker 1.

Add negative fixtures for each fail-closed boundary and assert the exact error line on stderr with empty stdout. The reported exact self-test success line (task report line 12) establishes only the current, incomplete fixture behavior.

### Important 2 — Rollback cleanup failure is ignored, so the gate can report success with a stale worktree

The core rollback operation is correctly isolated and uses the required argument sequence `git revert -m 1 --no-edit MERGE_SHA` in the detached worktree (review package lines 118–133); the real main checkout is not used for the revert. However, the `git worktree remove --force` result is discarded in `finally` (lines 134–139). A removal failure can therefore leave a registered temporary worktree and filesystem content while the acceptance path still returns PASS.

Treat cleanup failure as an acceptance failure (while preserving the original rollback/regression error if one already exists), and verify that the temporary worktree registration and directory are gone.

## Confirmed properties

- Task scope is correct in the supplied package: one commit is listed and the diff contains only the new `work/modes/accept.py` (review package lines 3–14, 19–24). The report identifies task parent `806fb63b782c45c0aa98939024e5a0a143d6e1fc` and head `85daade36a7e1506d397dc2f803308a821b386ea` (task report lines 3–7). Under the package-only constraint, no independent Git ancestry command was run.
- Merge grammar uses full lowercase 40-character SHAs and `_structure` requires the ledger tuple `(merge, frozen base, task 4 tip)` (review package lines 46, 85–91).
- A valid accepted merge must have exactly two parents, in the required order: parent 1 is the frozen base and parent 2 is the task tip (lines 90–91).
- Each task commit is required to be a single-parent commit with the exact prior chain parent, and each task's committed path set is checked against its owned group (lines 92–102).
- Rollback is performed in a detached temporary worktree and invokes `git revert -m 1 --no-edit MERGE_SHA`; the reverted tree is compared with the frozen base before regressions (lines 118–133).
- The self-test's stated happy-path stdout and empty stderr are exact (task report line 12), and `main` emits the documented success line (review package lines 210–218). Full accept-mode output cannot yet be demonstrated because, as the task report notes, the final ledger anchors and merge do not exist until task 4/controller integration (task report line 23).

## Standards axis

No separate documented repository-standard source was permitted by the review scope. Within the supplied diff, no additional hard standards violation or material baseline smell was identified beyond the contract and fail-closed findings above.

## Spec/contract axis summary

The exact merge-parent structure, per-task committed path scope, isolated revert command, and task-3 diff scope are present. Acceptance is nevertheless unsafe because four required gates remain bypassable: artifact existence, current-HEAD binding, real-checkout tracked/untracked cleanliness, and cumulative budget enforcement.
