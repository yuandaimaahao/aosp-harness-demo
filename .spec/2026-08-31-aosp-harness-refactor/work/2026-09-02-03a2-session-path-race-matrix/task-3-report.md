# 03a2 Task 3 implementation report

## Status

DONE

## Commit

- `b9582e51ab5769bee90016e7e3aadb9d895ffd12` — `test(session): execute session path race matrix`

## Task identity and scope

- `TASK_BASE`: `723bb71ecbfc075acd667fb0b0b7de8e78b026fd`
- `TASK_HEAD`: `b9582e51ab5769bee90016e7e3aadb9d895ffd12`
- Execution BASE: `6f26119e0f49891f033c1f63183a27344cf60bb5`
- Production diff remains exact one file: `tests/test-session-path-races.sh`.
- This task closes only the adapter seam. Foundation, provider, private driver, existing tests, spec正文, PLAN, STATE, ledger, and the controller-owned final manifest were not changed.

## Red evidence

红阶段证据: `task-3-red.log`

At `TASK_BASE`, the real dependency-present entrypoint returned rc `1`, stdout `0B`, stderr exact `29B` (`FAIL race adapter incomplete\n`) and no PASS. Independently, driver protocol returned rc0/`28B`/`0B`, and driver self-test returned rc0/`38B`/`0B`; provider/driver hashes were unchanged. This proves the only red was the intended entrypoint adapter seam.

## Implementation

- Added the expected driver result token and a case-log path directly under the absent `$TMP_TEST/driver` workspace.
- Replaced the sole transition failure with exactly one `python3 DRIVER run-matrix FOUNDATION PROVIDER WORKSPACE CASE_TSV CASE_LOG` invocation after the existing protocol/core classifier.
- Captured driver stdout and stderr separately, accepted only rc0, exact `RESULT PASS  session path race driver\n`, and empty stderr.
- Compared the produced case log byte-for-byte with the TSV first column, then reran matrix validation and required 37 log rows with 37 unique IDs before printing the sole assurance summary.
- The entrypoint still never calls `self-test`; the controller runs protocol/self-test independently.

## Local dynamic verification

- Real dependency-present no-arg and `all`: `2/2` rc0, exact stdout `41B`, stderr `0B`; real driver executed and the ordered 37-case log passed.
- Persisted fake-driver evidence proves exact argv sequence `protocol,run-matrix`, no `self-test`, 37 TSV rows/37 unique IDs, continuous counts `9/3/9/3/3/3/3/3/1`, and a byte-identical ordered 37-row case log.
- Dependency/argument/matrix fixtures: `35/35` passed; anchor cross-product `18/18`; every inert case created zero case rows. The controller's first final total assertion used `32` after all 35 per-case assertions had already passed; the corrected independent artifact count and inert-log checks passed at `35/35`.
- Adapter damage fixtures: `7/7` fail closed for run rc, run stderr, wrong summary, missing log, duplicate log, extra log, and reordered log; every case returned stdout `0B` with no assurance PASS.
- Foundation test, session-path test, driver protocol/self-test, and root offline gate passed. Offline found the race assurance summary exactly once and ended with the fixed offline PASS.
- Dependency hashes were unchanged throughout.

## Acceptance assets

Created under `acceptance/`:

- `accepted-default.out` — exact real default 41-byte assurance PASS.
- `fake-driver.argv` — exact two-line private CLI sequence.
- `matrix.tsv` — canonical 37-row four-column matrix.
- `case-log.expected` — ordered 37 case IDs matching TSV column one.
- `acceptance-report.md` — candidate/local/full/depth1/rollback and pending controller-gate evidence.

## Full, depth-1, and rollback

- Candidate implementation worktree: protocol/self-test/default/offline, fixed tools, assets, exact1/400, dependency hashes, and clean all PASS.
- Full clone at candidate HEAD: protocol `28B`, self-test `38B`, default `41B`, offline discovery once, hashes stable, clean.
- Real `git clone --depth 1 file://...`: same gates PASS, commit count exactly `1`, shallow marker nonempty, clean.
- Independent rollback clone: committed deletion of only the race entrypoint; driver self-test remained `38B`, offline PASS remained, race entrypoint discovery was `0`, 03b files were absent, clean.

## Static, size, and integrity gates

- Pinned shfmt `v3.14.0`, exact `-d -i 2 -ci -bn`: PASS.
- Pinned ShellCheck `0.11.0`, exact `-x --severity=warning`: PASS.
- `bash -n` and `git diff --check`: PASS.
- `TASK_BASE..TASK_HEAD`: `12 + / 1 -`, only the target script.
- Execution BASE through `TASK_HEAD`: exact one added target, `141 + / 0 -`; numstat total and physical size are both `141 <= 400`, mode `100755`.
- Foundation/provider/driver and existing tests have zero execution-range diff.
- Final dependency SHA-256 values:
  - foundation: `d3113933e57e59c7d942c60d48d69299bcef64da1c94ff464ea58b0f89767552`
  - provider: `07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`
  - driver: `cb8277c52bc6dd1591c78c58a0baee8fe1a0d7d17305380f0f79f5d745fd94c0`
- Post-commit implementation worktree is clean.

## Pending controller-only gates

Independent Task 3 diff review, the final three-line continuous PASS manifest, accepted ledger entry, and 03b order release remain intentionally pending until review PASS.

## Concerns

None.
