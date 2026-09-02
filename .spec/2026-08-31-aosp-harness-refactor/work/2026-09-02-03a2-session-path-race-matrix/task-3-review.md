# 03a2 Task 3 and final candidate independent review

## Verdict

**PASS** — Blocker: 0, Important: 0, Minor: 0.

Reviewed incremental range: `723bb71ecbfc075acd667fb0b0b7de8e78b026fd..b9582e51ab5769bee90016e7e3aadb9d895ffd12`.

Reviewed final execution range: `6f26119e0f49891f033c1f63183a27344cf60bb5..b9582e51ab5769bee90016e7e3aadb9d895ffd12`.

## Standards axis

PASS. No documented-standard violation or reportable smell was found. The Task 3 hunk is one cohesive driver-execution gate with descriptive constants and explicit ordered evidence checks. The short protocol and run-result capture blocks have distinct commands/contracts; extracting them would add abstraction without improving this single test entrypoint.

## Spec axis

PASS. Task 3 closes only the adapter seam, and the cumulative candidate satisfies the required entrypoint, dependency, rollback, size, and ordering surfaces.

## Driver execution and evidence gates

- The main process invokes exactly one `python3 DRIVER protocol` and one `python3 DRIVER run-matrix FOUNDATION PROVIDER WORKSPACE CASE_TSV CASE_LOG`. The recursive matrix-damage child exits before dependency classification. An independent fake-driver run produced exactly two argv rows (`protocol`, then six-field `run-matrix`) and zero `self-test` rows.
- Protocol and run-matrix stdout/stderr use separate files. Both require rc `0`, empty stderr, and an exact LF-terminated summary before proceeding.
- The supplied workspace is the uncreated physical path `$TMP_TEST/driver`; CASE_LOG is its direct child. The independent fake driver's exclusive `mkdir` succeeded, which would fail if the entrypoint had pre-created the workspace.
- Independent fake evidence contains exactly 37 four-column TSV rows, 37 unique canonical IDs, continuous family counts `9/3/9/3/3/3/3/3/1`, and a 37-row case log byte-identical to the TSV first column in order.
- Adapter damage independently passed `7/7`: run rc, run stderr, wrong summary, missing log, duplicate log, extra log, and reordered log all returned rc `1`, stdout `0B`, one FAIL diagnostic, and no assurance PASS.
- The Task 2 dependency classifier remains ordered and intact. The accepted report's dependency/argument/matrix suite is `35/35`, anchor cross-product `18/18`, and every inert branch creates zero case rows.

## Real candidate and checkout verification

- Real candidate no-arg and `all` each return rc `0`, exact `41B` stdout, and stderr `0B`; their outputs are byte-identical. The real driver executes and passes all 37 cases.
- Root `bash ./scripts/check.sh --offline` passes, discovers the race assurance summary exactly once, has empty stderr, and ends with the fixed offline PASS.
- Independent full clone at candidate HEAD passes protocol `28B`, self-test `38B`, default `41B`, offline discovery once, dependency SHA stability, and clean status.
- Independent real `git clone --depth 1 file://...` passes the same gates; commit count is exactly `1`, `.git/shallow` is nonempty, and status is clean.
- Independent rollback clone commits deletion of only `tests/test-session-path-races.sh`; driver self-test remains exact `38B`, offline remains PASS with race discovery count `0`, both 03b snapshot files are absent, and status is clean.

## Final size, tools, integrity, and audit assets

- Task 3 increment modifies only the target entrypoint (`12` additions, `1` deletion). The execution range is exact one added executable file, `tests/test-session-path-races.sh`, mode `100755`, numstat and physical size `141/400`.
- Foundation, provider, private driver, and the existing foundation/path tests have zero execution-range diff. Current dependency SHA-256 values match the red, implementation, and acceptance reports after all reruns.
- Pinned shfmt `v3.14.0` with exact `-d -i 2 -ci -bn`, ShellCheck `0.11.0` with exact `-x --severity=warning`, `bash -n`, range and worktree `git diff --check`, and implementation clean status all pass.
- Acceptance assets are mechanically auditable: `accepted-default.out` is exact `41B`; `fake-driver.argv` has exactly two valid rows and no self-test; `matrix.tsv` is 37×4 with 37 unique IDs and exact family counts; `case-log.expected` is byte-identical to its first column; `acceptance-report.md` records candidate/full/depth1/rollback results.
- The manifest currently has the two prior continuous PASS rows ending at Task 3 BASE, which is correct before this independent review is accepted. The 03a2 ledger has no premature final accepted HEAD.
- The 03b spec/work directory, worktree path, branch ref, execution-base, manifest, and dispatch brief are all physically absent; Git worktree/ref queries returned the required absence states.

The controller may now append the Task 3 PASS manifest row, rerun the final three-row/HEAD gate, enter dependency-present `37/37` acceptance evidence in the 03a2 ledger, and only then release 03b.
