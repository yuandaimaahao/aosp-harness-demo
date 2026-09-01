# Task 4 v5.5 fix round 1 report

## Status

DONE

## Commits

- `f91f54d3d9832c803097bf171e9628b8d1adedab` — `fix(session): support shallow quality checkouts`

## Red evidence

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03a-session-path-safety/task-4-v5.5-review-round1.md`

Round 1 reproduced the blocker in a depth-1 clone: the default path test attempted to resolve execution BASE `d68911b...`, emitted `fatal: bad object`, then failed with `FAIL foundation files changed`; the automatically discovered offline gate consequently failed too.

## Fix

- Removed the historical BASE/foundation `git diff` from the long-term default runtime test. Foundation immutability remains enforced by the controller's BASE..HEAD acceptance command.
- Changed `invoke` from the misleading `(label, project, session, env...)` protocol to `(project, session, env...)` and updated every caller.
- Modified only `tests/test-session-path.sh`; `common/.harness/lib/session-state-path.sh` retained SHA-256 `07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`.

## Shallow-clone regression

Cloned final candidate HEAD through the local file URL with `git clone --depth 1 --branch spec/2026-09-01-03a-session-path-safety file:///home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a-session-path-safety <fixture>`.

- Clone HEAD: `f91f54d3d9832c803097bf171e9628b8d1adedab`.
- `git rev-list --count HEAD`: exact `1`; `.git/shallow` exists and is non-empty.
- `bash ./tests/test-session-path.sh`: rc `0`, stdout byte-exact 33 bytes `RESULT PASS  session path safety\n`, stderr 0 bytes.
- `bash ./scripts/check.sh --offline`: rc `0`, stderr 0 bytes, final stdout line `RESULT PASS  aosp-harness offline quality gate`.

## Final tests and streams

All gates were rerun from committed HEAD:

- Default, `--case source-validate`, `--case roots-static`, and `--dependency-absent`: each rc `0`, stdout byte-exact 33-byte PASS with final LF, stderr 0 bytes.
- Real repository fixture retaining provider/test but physically lacking foundation, default and `--dependency-absent`: each rc `0`, same exact 33-byte stdout, stderr 0 bytes.
- `--case mutations`: rc `1`, stdout empty, stderr byte-exact `FAIL option: unsupported case mutations\n`.
- Extra-LF self-disproof: rc `1`, stdout empty, stderr byte-exact `FAIL default source-validate: streams or rc\n`.
- Managed-body location self-disproof with `before_mkdir` moved to `dispatch` while global count stayed one: rc `1`, stdout empty, stderr byte-exact `FAIL phase before_mkdir global or managed-body count\n`.
- `bash ./tests/test-session-state-foundation.sh`: PASS, stderr empty.
- `bash ./scripts/check.sh --offline`: PASS, stderr empty, final line `RESULT PASS  aosp-harness offline quality gate`.
- `bash -n common/.harness/lib/session-state-path.sh tests/test-session-path.sh` and `git diff --check`: rc `0`.

## Pinned tools and size gate

- shfmt binary `/tmp/aosp-gate-review.T8RDQ1/shfmt`: exact version `v3.14.0`; `-d -i 2 -ci -bn` on the exact two implementation files returned rc `0` with empty stdout/stderr.
- ShellCheck binary `/tmp/aosp-gate-review.T8RDQ1/shellcheck/shellcheck`: exact version field `0.11.0`; `-x --severity=warning` on the exact two implementation files returned rc `0` with empty stdout/stderr.
- Global BASE `d68911bde93f72d1e42dc85fba6271159e945170` to final HEAD name-only remains exact two owned files.
- Numstat is provider `114 + 0`, test `277 + 0`, total `391 <= 400`.
- Fix-round diff from `3fd9053d504a2bf48f59e450099ccdabeaf6b22d` contains only `tests/test-session-path.sh`; implementation worktree is clean.

## Concerns

None. The shallow-checkout blocker and ignored-argument minor are closed without weakening runtime or controller-owned immutability gates.
