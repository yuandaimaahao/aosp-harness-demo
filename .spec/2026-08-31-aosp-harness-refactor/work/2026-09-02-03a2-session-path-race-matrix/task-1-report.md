# 03a2 Task 1 implementation report

## Status

DONE

## Commits

- `1933dca8f0417947f54c41a79503b6fe03cfdf5c` — `test(session): add race matrix gate`
- `8ef44f1b59e67c02dacc695b2eef0c2b6fc87a9a` — `fix(test): make race matrix gate portable`

## Task identity and scope

- `TASK_BASE`: `6f26119e0f49891f033c1f63183a27344cf60bb5`
- `TASK_HEAD`: `8ef44f1b59e67c02dacc695b2eef0c2b6fc87a9a`
- BASE was independently verified as the implementation worktree HEAD and a 40-hex commit before editing.
- Production diff is exact one added file: `tests/test-session-path-races.sh`.
- Task 2 provider/anchor/driver/core classifier and Task 3 driver adapter were not implemented. The dependency-present path intentionally ends only at `dependency classifier incomplete`.

## Red evidence

红阶段证据: `task-1-red.log`

Before creation, `tests/test-session-path-races.sh` was physically absent (`! -e && ! -L`). Running:

```text
bash tests/test-session-path-races.sh
```

returned rc `127`, stdout `0B`, no `RESULT PASS`, and stderr `66B`:

```text
bash: tests/test-session-path-races.sh: No such file or directory
```

This is the required real file-absence red rather than a temporary same-name implementation failure.

## Implementation

- Added physical repo-root/temp ownership and the three accepted CLI shapes: no args, `all`, and `--dependency-absent`; unknown/extra/value forms fail rc1 with stdout empty.
- The tracked entrypoint is mode `100755`, so the fixed direct rollback command surface launches without a shell wrapper. Script setup exports `LC_ALL=C` before matrix construction and validation.
- Added the canonical four-column 37-row matrix in the fixed `9/3/9/3/3/3/3/3/1` family order plus independent 37-line/37-unique/continuous-family validation before any dependency read.
- Added the sole test-only `HARNESS_TEST_MATRIX_DAMAGE` duplicate-row mutation and recursive provider-absent child self-disproof. The damaged child fails at matrix validation before recursion and no skip-fixture seam exists.
- Added the provider-absent inert surface in a new Bash process. It proves private core, the four state public functions and `HARNESS_SESSION_STATE_PROVIDER_VERSION` are absent, then emits only the exact assurance summary.
- Provider-present execution deliberately returns rc1 with exact stderr `FAIL dependency classifier incomplete\n`, stdout 0B and no driver call.

## Green verification

- Same isolated provider/foundation/driver-absent root, using the tracked executable directly with the caller locale unset:
  - no args: rc0, stdout exact `41B`, stderr `0B`;
  - `all`: rc0, stdout exact `41B`, stderr `0B`;
  - `--dependency-absent`: rc0, stdout exact `41B`, stderr `0B`.
- Invalid CLI:
  - `unknown`, `all extra`, and `--dependency-absent value`: each rc1, stdout `0B`, no PASS.
- Matrix self-disproof with provider/foundation/driver simultaneously absent: rc1, stdout `0B`, no PASS, before inert selection.
- An isolated retained-temp probe inspected the generated data independently: primary matrix 37 rows, 37 unique IDs, and exact continuous counts `9/3/9/3/3/3/3/3/1`; recursive damaged matrix had 38 rows.
- Real dependency-present worktree, using the tracked executable directly with both no arguments and `--dependency-absent`: each rc1, stdout `0B`, stderr exact `38B` ending in `dependency classifier incomplete`. An exported fake `python3` callback was not invoked, mechanically proving zero driver calls in Task 1.
- `bash -n`, pinned shfmt `v3.14.0` with `-d -i 2 -ci -bn`, pinned ShellCheck `0.11.0` with `-x --severity=warning`, and `git diff --check` all passed.

## Exact size and dependency integrity

- `TASK_BASE..TASK_HEAD` name-status: exact `A tests/test-session-path-races.sh`.
- Numstat: `95 + / 0 -`; total `95 <= 400`.
- Physical entrypoint size: `95 <= 400` lines; tracked mode is `100755`.
- Dependency range diff for foundation/provider/driver: zero paths.
- Before and after SHA-256 values are identical:
  - foundation: `d3113933e57e59c7d942c60d48d69299bcef64da1c94ff464ea58b0f89767552`
  - provider: `07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`
  - private driver: `cb8277c52bc6dd1591c78c58a0baee8fe1a0d7d17305380f0f79f5d745fd94c0`
- Post-commit `git status --porcelain` is empty; implementation worktree is clean.

## Concerns

None. The dependency-present failure is the intentional Task 2 red seam and must not be treated as a completed 03a2 entrypoint.
