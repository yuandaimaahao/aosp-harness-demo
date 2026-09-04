# Task 1 evidence-only incremental review (r2)

## Conclusion: FAIL

This review was limited to the newly supplied evidence/report inputs plus read-only worktree identity checks.  No full test was rerun and no implementation file was changed.

## Evidence checks

- `task-1-red.txt` (407 B, SHA-256 `633a…bfff`) and `task-1-static.log` (400 B, `eb36…a56b`) match their package rows. The red record says rc 1, empty stdout, first failure `FAIL monotonic attempt count`, and cleanup absent; static records `2/2`, provider/prototype cmp, two APIs, one seam, and the three zero-exit static commands.
- `task-1-green.out` is exactly 38 B, SHA-256 `0efd…0855`, and byte-compares with `RESULT PASS  resource lease assurance\n`; `task-1-green.err` is exactly 0 B with the empty-file SHA-256. Both, and `task-1-green-command.log` (1,177 B, `587f…3abd`), match `task-1-package.tsv`.
- The green command log consistently records rc 0, those stream byte counts, a repo-external ordinary four-file layout, its four copied-file hashes, and `temp_before_absent: PASS` / `temp_after_absent: PASS`. The named green temporary path is physically absent now.
- The implementation worktree remains clean at `3ab44a5430d9038d20ec143ebe2c0846349f584e`; the parent-to-HEAD provider numstat remains exactly `2/2`. The logged provider/docs/base-test hashes match the current worktree.

## Specification compliance

| Requirement | Result | Review evidence |
|---|---|---|
| R1 | ✅ | The unchanged commit remains exact one-file `2/2` scope and retains the prescribed two-line deadline split. Public API/seam and unrelated source surfaces are unchanged by this commit. |
| R2 | ✅ | The source control flow remains correct: post-scan reached deadline takes `continue`, so the next loop begins with `flock` without executing `sleep`; the acquired-lock deadline guard precedes recovery, record reads, stale removal, and publication. `wait=0` and no-contention branches are unchanged. |

No `EvidenceRecord` is present in the project context; the R1/R2 assessment is therefore against requirements/design/brief, not invented E-IDs.

## Quality conclusion

- YAGNI, duplication, and error ordering: ✅ The minimal provider-only control-flow patch remains appropriate, and unlock still occurs in the enclosing `finally` before the final-loop retry.
- Verification authenticity: ❌ The fourth green input cannot be tied to the stated prototype. `task-1-green-command.log` records copied assurance-script SHA-256 `0bf21e8f…27690b`, whereas the only current tracked prototype at the brief's `prototypes/assurance/tests/test-resource-leases-assurance.sh` path hashes to `6ccacda…9ce8d` (20,831 B). The logged `0bf…` value is not a current tracked blob, and neither the package nor report identifies another authorized source path/hash. Thus the green artifact proves an unknown assurance script passed, not that the required prototype assurance passed.

## Findings

| Severity | Finding | Minimum fix |
|---|---|---|
| B | None | — |
| I | Green assurance-input provenance is unverifiable: the logged assurance hash differs from the only current authorized prototype and has no identified source. This invalidates the claimed prototype-assurance verification despite valid output/rc hashes. | Recreate the repo-external four-file green fixture from the current explicitly named prototype, record the source path and SHA-256 along with the copied-file SHA-256 (they must match), then rerun only that captured green command and update its package/report rows. |
| M | None | — |
