# Task 1 report: resource lease final attempt

Status: DONE

## Scope

- Changed only `common/.harness/lib/resource-leases.sh`.
- Replaced the post-scan deadline exit with the required two-line control flow: `not occupied|wait=0` exits with rc 3, while a reached deadline immediately continues to the final no-sleep flock attempt.
- Public API, state format, docs, base test, and the single `HARNESS_RESOURCE_LEASE_TEST_SEAM` occurrence are unchanged.

## Verification

- Red repo-external four-file tree: rc 1, empty stdout, first dedicated failure `FAIL monotonic attempt count`; evidence: `evidence/task-1-red.txt`.
- Fixed static checks: shfmt v3.14.0 (`-d -i 2 -ci -bn`), ShellCheck 0.11.0 (`-x --severity=warning`), and `bash -n`: all rc 0. Provider/prototype `cmp` passed; API count is 2 and seam count is 1; evidence: `evidence/task-1-static.log`.
- Green repo-external four-file tree using the repaired provider and the sole assurance source `/tmp/aosp-harness-publish-04-main.AGaEae/.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-04-04a-runtime-resource-lease-assurance/prototypes/tests/test-resource-leases-assurance.sh` (SHA-256 `0bf21e8f9d29e5a87cdcc8e962ede20143ccbf49fcb742756923f519b327690b`, 24945 bytes, 396 lines): source/copy `cmp -s` rc 0, all four source/copy hashes and sizes match, test rc 0, stderr empty, stdout exactly `RESULT PASS  resource lease assurance`; assurance matrix completed its monotonic final-attempt oracle and related checks.
- Commit is exact one-file scope with numstat 2/2 and a clean worktree.

## Commit

`3ab44a5430d9038d20ec143ebe2c0846349f584e` (`fix(resource-lease): retry once at deadline`)

## Evidence package

`evidence/task-1-package.tsv` records the red/static/green/provider/commit evidence, including the raw green stdout/stderr and source-verified command log. The controller owns `review-manifest.tsv` and will add the task row after independent review PASS; this task did not create or modify that manifest.

## Concerns

None.

Final status: DONE
