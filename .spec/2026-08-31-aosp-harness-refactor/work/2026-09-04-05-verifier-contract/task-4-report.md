# task-4 report: candidate audit and accepted-head recommendation

## status

DONE

## candidate

- Candidate / task-3 HEAD: `9e5edb45a3048e4c208e2d7fe135639768cc87db` (`docs(harness): define verifier contract`).
- Candidate worktree was clean before and after the audit (`git status --porcelain` = 0 bytes).
- This is a zero-source-delta audit: no commit was created, and `git diff 9e5edb45a3048e4c208e2d7fe135639768cc87db HEAD` is empty.

## red phase

The pre-audit command `test -s "$WORK/task-4-report.md"` returned rc 1 with empty stdout and stderr while the report was absent. The recorded candidate was already clean at `9e5edb45a3048e4c208e2d7fe135639768cc87db`.

红阶段证据: `/tmp/aosp-harness-publish-04-main.AGaEae/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/evidence/task-4-red.txt`

## commands and results

- Fixed tools: `/tmp/aosp-harness-tools-04/shfmt --version` = `v3.14.0`; `/tmp/aosp-harness-tools-04/shellcheck --version` = `0.11.0`. For both executable delivery files, `bash -n`, fixed `shfmt -d -i 2 -ci -bn`, and fixed `shellcheck -x --severity=warning` returned rc 0 without diagnostics.
- Base contract: `bash ./tests/test-verifier-contract.sh` returned rc 0; stdout was byte-for-byte `RESULT PASS  verifier contract\n`; stderr was 0 bytes.
- Offline gate: `bash ./scripts/check.sh --offline` returned rc 0; stderr was 0 bytes and its final stdout line was exactly `RESULT PASS  aosp-harness offline quality gate`.
- Scope: `git diff --check 65d67b52e5b34d0d9d2add587083ebf2fadcd3ea HEAD` passed. Its name set is exactly `common/.harness/bin/verify-sidebar.sh`, `docs/verifier-contract.md`, and `tests/test-verifier-contract.sh`; numstat is `202 0`, `67 0`, `102 0` (exact3, 371 additions, 0 deletions, 371 total).
- Independent review: current document and base test are byte-identical to their available controller prototypes; protected legacy verifier, session, and resource-lease paths have zero changes from the execution base; task-3 HEAD to candidate has zero source diff.

## cleanup and scope

The interrupted prior run had left 506 owned `/tmp/verifier-contract.*` test directories containing only regular test-capture files. After confirming no verifier/offline process remained, all 506 were removed; five task-local external command-log files were also removed. No repository file was changed apart from this task report. `ledger`, `review-manifest.tsv`, `STATE`, task checkboxes, and the original user worktree were untouched.

## accepted-head recommendation

Recommend controller fixation of `ACCEPTED_HEAD=9e5edb45a3048e4c208e2d7fe135639768cc87db` after its controller-owned manifest/ledger actions.

## test summary

Candidate audit passed: fixed shfmt/ShellCheck and syntax, exact-output verifier contract, offline quality gate, diff-check, exact3/371 scope, prototype parity, protected-path audit, zero source delta, cleanup, and clean-worktree checks.
