# 03a2 Task 2 implementation report

## Status

DONE

## Commit

- `723bb71ecbfc075acd667fb0b0b7de8e78b026fd` — `test(session): classify race dependencies`

## Task identity and scope

- `TASK_BASE`: `8ef44f1b59e67c02dacc695b2eef0c2b6fc87a9a`
- `TASK_HEAD`: `723bb71ecbfc075acd667fb0b0b7de8e78b026fd`
- Execution BASE remains `6f26119e0f49891f033c1f63183a27344cf60bb5`.
- Task diff modifies only `tests/test-session-path-races.sh`.
- This task implements only `dependency-classifier-v1`; it does not call `run-matrix` or `self-test`, create a driver workspace/case log, or implement the Task 3 adapter.

## Red evidence

红阶段证据: `task-2-red.log`

At `TASK_BASE`, real dependency-present execution of `bash tests/test-session-path-races.sh` returned rc `1`, stdout `0B`, stderr exact `38B` (`FAIL dependency classifier incomplete\n`), and no PASS summary. An exported recording `python3` boundary produced no argv log, proving zero driver calls. Provider and driver SHA-256 values were unchanged before and after.

## Implementation

- Added fixed foundation/driver paths and the expected `session-path-race-driver-v1\n` token while preserving physical repo-root resolution, mode `100755`, and `LC_ALL=C`.
- Assigned the accepted CLI forms to `all` or `dependency-absent` without widening the Task 1 argument surface.
- Added an isolated `core_available` oracle that sources the tracked foundation and provider in a fresh Bash process and accepts only a declared `_harness_session_path_core`.
- Replaced the Task 1 transition with the required order: provider absent inert; three anchors each exact once; driver absent inert or symlink/nonregular fail closed; separate protocol stdout/stderr capture with exact byte comparison; only then flag/foundation/core inert; otherwise exact `race adapter incomplete` transition failure.
- The classifier never defines the four state public APIs or provider marker and never calls the Task 3 adapter.

## Dynamic verification

- Real healthy dependency-present transition: rc `1`, stdout `0B`, stderr exact `29B` (`FAIL race adapter incomplete\n`); tracked dependency SHA values unchanged.
- Shared recording fake driver:
  - healthy provider: argv log exact one line `protocol`;
  - provider absent: argv log physically absent and inert PASS;
  - three anchors × missing/duplicate × foundation-missing/core-unavailable/flag: all `18/18` rc1 with exact anchor diagnostic, stdout `0B`, and argv log physically absent.
- Fourteen additional isolated classifier fixtures passed:
  - six zero-call states: provider absent default/flag, driver absent default/flag, driver symlink, and driver directory;
  - eight one-call states: healthy transition; protocol mismatch, syntax failure, rc failure, and stderr contamination; foundation absent, core unavailable, and explicit flag;
  - every one-call log contained only `DRIVER protocol`; none contained `run-matrix` or `self-test`.
- Driver-damage priority representatives passed `3/3`: symlink plus flag failed before protocol; protocol mismatch plus foundation absence and protocol stderr plus core unavailable each failed after exactly one protocol call rather than becoming inert.
- Task 1 regression surface passed `7/7`: provider-absent no-arg/all/flag returned exact rc0/`41B`/`0B`; unknown, extra, flag-with-value, and matrix duplicate returned rc1 with stdout `0B` and no PASS. Matrix damage still precedes inert classification.
- Existing dependencies passed unchanged: foundation test, session-path test, driver protocol exact `28B`/`0B`, and driver self-test exact `38B`/`0B`.

## Static, size, and integrity gates

- `bash -n tests/test-session-path-races.sh`: PASS.
- Pinned shfmt `v3.14.0`, exact argv `-d -i 2 -ci -bn`: PASS with no diff.
- Pinned ShellCheck `0.11.0`, exact argv `-x --severity=warning`: PASS with no diagnostic.
- `git diff --check`: PASS.
- `TASK_BASE..TASK_HEAD`: `36 + / 1 -`, only the target script.
- Execution BASE through `TASK_HEAD`: exact one added file, `tests/test-session-path-races.sh`, `130 + / 0 -`; total and physical size are both `130 <= 400`, tracked mode `100755`.
- Foundation/provider/driver and existing foundation/path tests have zero execution-range diff.
- Dependency SHA-256 values remained unchanged:
  - foundation: `d3113933e57e59c7d942c60d48d69299bcef64da1c94ff464ea58b0f89767552`
  - provider: `07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`
  - driver: `cb8277c52bc6dd1591c78c58a0baee8fe1a0d7d17305380f0f79f5d745fd94c0`
- Post-commit implementation worktree is clean.

## Concerns

None. The healthy dependency-present `race adapter incomplete` failure is the intentional Task 3 red seam, so the offline gate is not expected to pass until Task 3 closes the adapter.
