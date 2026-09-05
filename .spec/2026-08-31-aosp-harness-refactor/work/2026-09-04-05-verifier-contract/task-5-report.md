# task-5 report: verifier checkout contract

## status

DONE

## red phase

Before writing this report, `test -s "$WORK/task-5-report.md"` returned rc 1 with
empty stdout and stderr, as required for the absent-report precondition.  The
candidate was already clean at `9e5edb45a3048e4c208e2d7fe135639768cc87db`.

红阶段证据: `/tmp/aosp-harness-publish-04-main.AGaEae/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/evidence/task-5-red.txt`

## checkout evidence

- Candidate: HEAD is exactly `9e5edb45a3048e4c208e2d7fe135639768cc87db`, the
  worktree is clean, and `git diff ACCEPTED_HEAD HEAD` is empty.
- Full-history clone: a real `git clone file://...` outside the repository
  reached the same HEAD, had more than one reachable commit, was clean, and
  passed `git diff --check`.  Its diff from
  `65d67b52e5b34d0d9d2add587083ebf2fadcd3ea` is exactly the three canonical
  files: `common/.harness/bin/verify-sidebar.sh`,
  `docs/verifier-contract.md`, and `tests/test-verifier-contract.sh`.
- Depth-1 clone: a real `git clone --depth 1 file://...` outside the repository
  reached the same HEAD, was clean, had `rev-list --count HEAD = 1`,
  `rev-parse --is-shallow-repository = true`, and a non-empty `.git/shallow`.
  The full-history clone establishes the exact3 diff for this identical HEAD;
  the shallow clone cannot diff its intentionally unavailable base object.

For candidate, full, and depth-1 checkouts, `bash ./tests/test-verifier-contract.sh`
returned rc 0 with a 0-byte stderr and stdout byte-for-byte equal to
`RESULT PASS  verifier contract\\n`.  In each checkout,
`bash ./scripts/check.sh --offline` returned rc 0 with a 0-byte stderr and final
stdout line exactly `RESULT PASS  aosp-harness offline quality gate`.

## cleanup and source scope

The owned external directory `/tmp/verifier-contract-task5.S7XCKN` contained
only this task's full and depth-1 clones and captured command output.  It was
explicitly removed after all assertions; its existence check is now false.

This is a zero-source-delta verifier task: no source commit was created and
the accepted candidate remains clean with zero diff from `ACCEPTED_HEAD`.
`ledger`, `review-manifest.tsv`, `STATE`, task checkboxes, and the original user
worktree were not modified.

## test summary

Candidate, full-history `file://`, and real depth-1 `file://` checkouts all
passed the exact-output verifier contract and offline quality gate; full exact3,
depth-1 single-commit/shallow proof, clean checks, and external cleanup passed.
