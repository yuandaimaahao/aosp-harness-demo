# task-2.1 independent review r1

## Verdict

**PASS — B=0, I=0, M=0.**  Candidate `f7cfcb202d1fd2934d07cc90e333a4205b563243` may be fixed as `ACCEPTED_HEAD`.

Reviewed as a fresh, independent, zero-diff review.  The implementation worktree only was read; no source, index, HEAD, or implementation-worktree file was changed.

## Specification compliance

| Required review point | Independent result |
|---|---|
| RED proves the report was absent | PASS. `evidence/task-2.1-red.txt` is 437 B, SHA-256 `ce02ef89bd6aed7c67f1d578537ff3498908df6b93f429c4eb19c830d19fec3a`, and records `test -s .../task-2.1-report.md` rc=1 / `report_exists: no`. Its mtime (`16:59:47`) precedes the report mtime (`17:07:05`). |
| Candidate unchanged and clean | PASS. Before and after review, `HEAD` was the required full 40-hex candidate; `git status --porcelain=v1` was empty. The supplied `f7cfcb20..f7cfcb20` package is an empty diff/stat. |
| Fixed tools and static checks | PASS. Exact versions: shfmt `v3.14.0`, ShellCheck field `0.11.0`. On only the provider and base test, shfmt diff, ShellCheck warning level, and `bash -n` all returned rc0 with empty output. |
| Prototype / exact sizing / scope | PASS. Each final path is byte-identical to its spec prototype (`cmp` rc0): provider 336 lines/SHA `011d4804…746af`; docs 7/`f16ea8af…3dea`; test 57/`d2f324a3…a0983`; both totals are 400. `BASE..candidate` name-only is exactly the three allowed paths; numstat is `336+7+57`, additions 400 and deletions 0. |
| Assurance boundary | PASS. `tests/test-resource-leases-assurance.sh` is physically absent. Provider seam count is 1, test seam count is 0, and provider session-version marker count is 0. |
| Default / all protocol | PASS. Both commands returned rc0, stdout exactly 29 B / SHA `91cc39b0d798a121e52ca21cb7aa42970725c9afa25229a4b99d782cf79a821b` (`RESULT PASS  resource leases\n`), stderr 0 B. |
| Invalid argv protocol | PASS. `all extra`, `unknown`, and `--x value` each returned rc1 with stdout and stderr both 0 B (empty-stream SHA-256). |
| Offline discovery | PASS. `bash ./scripts/check.sh --offline` returned rc0, stderr 0 B, stdout 603 B / SHA `2c58ffd67925744312239804178e80401c2376395528499ea1c7e2c756da7a2a`; `RESULT PASS  resource leases` occurs exactly once and the final line is `RESULT PASS  aosp-harness offline quality gate`. |
| Diff hygiene | PASS. `git diff --check BASE candidate` and worktree `git diff --check` both returned rc0 with no output. |

The implementation report and evidence package are internally consistent and their hashes/byte counts were recomputed from the actual evidence files. Package SHA-256 is `98e956b5caaee0dae94cbc1bacfb18873c4aaf8d3c8331f3bfd92a9c5d4adf68` (1133 B); static evidence SHA-256 is `6ec4b2bec81da638b8eca956ef44680aada7d10e11daa4fb47b154fc3eef3014` (2590 B). No hash or fact claimed by the report and checked here disagreed with the underlying evidence.

## Quality

PASS. This task is an audit with no implementation diff. Its zero-diff package is genuinely empty, it does not introduce out-of-scope files or duplicate logic, and its evidence checks assert concrete return codes, exact byte streams, discovery cardinality, static-tool results, and Git scope/hygiene rather than merely running commands. Error-path coverage is specifically present for all three required invalid invocations.

## Findings

None.

**B=0 / I=0 / M=0.**
