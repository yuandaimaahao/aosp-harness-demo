# 03a2 Task 3 candidate acceptance report

## Verdict

PASS for candidate implementation evidence.

The independent Task 3 diff review, final three-row review manifest, ledger acceptance entry, and 03b release-order gate remain controller-owned and intentionally pending.

## Candidate identity

- Execution BASE: `6f26119e0f49891f033c1f63183a27344cf60bb5`
- Task 3 BASE: `723bb71ecbfc075acd667fb0b0b7de8e78b026fd`
- Candidate HEAD: `b9582e51ab5769bee90016e7e3aadb9d895ffd12`
- Commit: `test(session): execute session path race matrix`
- Execution range: exact one added file, `tests/test-session-path-races.sh`, mode `100755`, numstat and physical size `141/400`.

## Dependency-present delivery

- Real no-argument and `all` entrypoint calls both returned rc0, stdout exact `41B`, stderr `0B`.
- Independent driver protocol returned exact `session-path-race-driver-v1\n` (`28B`); independent self-test returned exact `RESULT PASS  session path race driver\n` (`38B`).
- The entrypoint invoked the real driver through the validated 37-row matrix and accepted only the ordered 37-case log.
- Offline discovery ran the race entrypoint exactly once and ended with `RESULT PASS  aosp-harness offline quality gate`.
- Foundation and session-path regression tests passed.

## Persisted fake-driver evidence

- `fake-driver.argv`: exact two calls, first `protocol`, second `run-matrix` with six TSV fields; no `self-test`.
- `matrix.tsv`: 37 rows and 37 unique IDs in the required continuous family counts `9/3/9/3/3/3/3/3/1`.
- `case-log.expected`: 37 rows, byte-identical to `matrix.tsv` first-column IDs in order.
- The fake driver successfully created the supplied absent workspace and its direct-child case log; an already-existing workspace would have failed its exclusive creation path.
- `accepted-default.out`: exact `RESULT PASS  session path race assurance\n` (`41B`).

## Fail-closed and inert fixtures

- Dependency/argument/matrix suite: `35/35` passed, including provider absent, driver absent/type/protocol damage, foundation/core/flag inert, invalid argv, and matrix damage before dependency inspection.
- Anchor cross-product: `18/18` missing/duplicate × foundation-missing/core-unavailable/flag failed before driver invocation.
- Adapter damage suite: `7/7` passed for run rc, run stderr, wrong summary, and missing/duplicate/extra/reordered case logs; all returned rc1 with stdout `0B` and no assurance PASS.
- All inert fixtures had zero case-log creation; foundation/core/flag invoked only `protocol`, never `run-matrix` or `self-test`.

## Fixed tools and integrity

- shfmt version exact `v3.14.0`; `shfmt -d -i 2 -ci -bn tests/test-session-path-races.sh` passed.
- ShellCheck version field exact `0.11.0`; `shellcheck -x --severity=warning tests/test-session-path-races.sh` passed.
- `bash -n` and `git diff --check` passed.
- Current foundation/provider/driver SHA-256 values were unchanged before and after all local and checkout tests:
  - foundation: `d3113933e57e59c7d942c60d48d69299bcef64da1c94ff464ea58b0f89767552`
  - provider: `07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`
  - driver: `cb8277c52bc6dd1591c78c58a0baee8fe1a0d7d17305380f0f79f5d745fd94c0`
- Implementation worktree remained clean.

## Checkout and rollback evidence

- Full clone at candidate HEAD: protocol 28B, self-test 38B, default 41B, offline discovery exactly once, dependency SHA stable, clean.
- Real `file://` depth-1 clone: same gates passed; commit count exactly `1` and `.git/shallow` nonempty.
- Independent rollback clone: removed and committed only `tests/test-session-path-races.sh`; driver self-test remained exact 38B, offline gate passed, race assurance discovery count was `0`, 03b snapshot files remained absent, and checkout was clean.

## Pending controller-only gates

- Independent Task 3 diff review: PASS, blocker/important/minor all zero.
- Final six-column manifest: PASS, exactly three continuous rows from execution BASE through accepted HEAD.
- Controller exact-stream/default/offline/tool/dependency/exact1/clean gate: PASS at accepted HEAD `b9582e51ab5769bee90016e7e3aadb9d895ffd12`.
- Controller persisted-matrix gate: PASS, `37/37`, continuous family counts `9/3/9/3/3/3/3/3/1`, ordered case log, fake argv exactly `protocol,run-matrix`.
- 03b order gate immediately before ledger acceptance: PASS; spec/work/branch/worktree/execution-base/manifest/dispatch were all physically absent.
