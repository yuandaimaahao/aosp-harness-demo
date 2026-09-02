# 03a2 Task 2 independent review

## Verdict

**PASS** — Blocker: 0, Important: 0, Minor: 0.

Reviewed incremental range: `8ef44f1b59e67c02dacc695b2eef0c2b6fc87a9a..723bb71ecbfc075acd667fb0b0b7de8e78b026fd`.

## Standards axis

PASS. No documented-standard violation or reportable smell was found. The increment is a short linear classifier with descriptive dependency constants and a focused isolated `core_available` oracle. The marker loop consolidates repeated checks; the small overlap between the two isolated-shell oracles serves different assertions and does not warrant abstraction.

## Spec axis

PASS. The implementation matches the Task 2 classifier contract, preserves the Task 1 surface, and does not enter Task 3 scope.

## Priority and stream evidence

- Source order is fixed as required: matrix/self-disproof; provider physical absence; three provider anchors exact once; driver symlink/nonregular and physical absence; exact driver protocol; explicit flag/foundation/core availability; the sole healthy transition seam `race adapter incomplete`.
- Independent controller fixtures passed all `18/18` anchor combinations: three anchors × missing/duplicate × foundation absent/core unavailable/flag. Every case returned rc `1`, stdout `0B`, exact anchor diagnostic, and a physically absent or zero-byte fake-driver argv log.
- Provider absence for no args, `all`, and `--dependency-absent` returned the exact inert summary with zero driver calls. Driver absence for default/flag also returned exact inert PASS with zero calls; driver symlink and directory failed before protocol with zero calls.
- Protocol stdout and stderr are captured in separate files. Nonzero execution, syntax failure, protocol mismatch, and stderr contamination all fail closed. Downstream foundation absence, core unavailability, and explicit flag each invoke only `protocol` once, then return the exact inert summary; no fixture log contains `run-matrix` or `self-test`.
- Three representative damage-priority combinations passed: symlink plus flag fails before protocol; protocol mismatch plus foundation absence fails at protocol; protocol stderr plus core unavailable fails at protocol. Downstream inert states cannot mask upstream damage.
- With the real tracked dependencies, default returns rc `1`, stdout `0B`, exact `29B` stderr `FAIL race adapter incomplete\n`, and exactly one recorded `DRIVER protocol` call. Real `--dependency-absent` returns rc `0`, exact `41B` stdout, stderr `0B`, also after exactly one protocol call.

## Scope, regression, and mechanical gates

- Incremental diff is only `tests/test-session-path-races.sh` (`36` additions, `1` deletion). Cumulative execution range is exact one added executable file, `130` additions/physical lines (`130/400`).
- Production source contains neither a `run-matrix` invocation nor `self-test`, creates no driver workspace/case-log adapter, and retains exactly one `race adapter incomplete` terminal seam.
- The Task 1 CLI, matrix duplicate priority, canonical 37 rows/nine continuous family counts, recursive self-disproof, inert surface, mode `100755`, and `LC_ALL=C` remain intact.
- Foundation, provider, private driver, and existing foundation/path tests have zero cumulative range diff. Current dependency SHA-256 values match the task red/report evidence.
- Existing foundation test, session-path test, driver protocol (`28B`) and driver self-test (`38B`) independently pass with empty stderr.
- Pinned shfmt `v3.14.0` with exact `-d -i 2 -ci -bn`, ShellCheck `0.11.0` with exact `-x --severity=warning`, `bash -n`, range `git diff --check`, dependency zero-diff, and implementation worktree-clean checks pass.

Task 3 may be dispatched.
