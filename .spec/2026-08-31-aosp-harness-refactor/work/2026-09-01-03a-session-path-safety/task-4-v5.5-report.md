# Task 4 v5.5 implementation report

## Status

DONE

## Commits

- `3fd9053d504a2bf48f59e450099ccdabeaf6b22d` — `test(session): fit path contract within quality gate`

## Red evidence

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03a-session-path-safety/task-4-fix1-red-foundation.log`

The v5.5 correction starts from the three prior task 4 review failures recorded in:

- `task-4-fix1-red-foundation.log`: a real provider/test fixture with the foundation file physically absent failed before the inert branch.
- `task-4-fix1-red-stream.log`: command substitution masked an extra trailing LF.
- `task-4-fix1-red-static.log`: pinned ShellCheck reported warnings and pinned shfmt produced a diff.

## Implementation

- Removed the complete `--case mutations` selector, default child, provider-copy replacement driver, and dynamic mutation body. `source-validate`, `roots-static`, the deterministic non-anchor post-mkdir disappearance probe, 2x2 isolation, and all static root/project/session attacks remain.
- Kept the provider byte-for-byte unchanged. The structure oracle now extracts the lexical `open_managed` body and requires each anchor once globally plus each checkpoint phase once globally and once inside that body; it also rejects `fchmod`.
- Made only the provider globally mandatory. With the foundation present, default runs `source-validate` then `roots-static`; with the real foundation file absent, default and `--dependency-absent` both run the all-missing inert oracle.
- Replaced child command-substitution checks with expected-file/`cmp` checks that preserve the final LF, and removed the unused `invoke` local flagged by ShellCheck.

## Exact tests and streams

All commands below were rerun from committed HEAD `3fd9053d504a2bf48f59e450099ccdabeaf6b22d`:

- `bash ./tests/test-session-path.sh`: rc `0`, stdout byte-exact 33 bytes `RESULT PASS  session path safety\n`, stderr 0 bytes.
- `bash ./tests/test-session-path.sh --case source-validate`: rc `0`, same exact 33-byte stdout, stderr 0 bytes.
- `bash ./tests/test-session-path.sh --case roots-static`: rc `0`, same exact 33-byte stdout, stderr 0 bytes.
- `bash ./tests/test-session-path.sh --dependency-absent`: rc `0`, same exact 33-byte stdout, stderr 0 bytes.
- In a repository fixture retaining the real provider/test but physically lacking the foundation file, default and `--dependency-absent`: each rc `0`, same exact 33-byte stdout, stderr 0 bytes.
- `bash ./tests/test-session-path.sh --case mutations`: rc `1`, stdout 0 bytes, stderr byte-exact `FAIL option: unsupported case mutations\n`.
- `bash ./tests/test-session-state-foundation.sh`: rc `0`, stderr 0 bytes, final stdout line `RESULT PASS  session state foundation`.
- `bash ./scripts/check.sh --offline`: rc `0`, stderr 0 bytes, final stdout line `RESULT PASS  aosp-harness offline quality gate`.
- `bash -n common/.harness/lib/session-state-path.sh tests/test-session-path.sh`: rc `0`.
- `git diff --check`: rc `0`.

## Pinned tool gate

- `/tmp/aosp-gate-review.T8RDQ1/shfmt --version`: exact `v3.14.0`.
- `/tmp/aosp-gate-review.T8RDQ1/shellcheck/shellcheck --version`: version field exact `0.11.0`.
- `/tmp/aosp-gate-review.T8RDQ1/shfmt -d -i 2 -ci -bn common/.harness/lib/session-state-path.sh tests/test-session-path.sh`: rc `0`, stdout/stderr 0 bytes.
- `/tmp/aosp-gate-review.T8RDQ1/shellcheck/shellcheck -x --severity=warning common/.harness/lib/session-state-path.sh tests/test-session-path.sh`: rc `0`, stdout/stderr 0 bytes.

## Exact files and numstat

Global BASE: `d68911bde93f72d1e42dc85fba6271159e945170`.

```text
114  0  common/.harness/lib/session-state-path.sh
278  0  tests/test-session-path.sh
```

- BASE..HEAD name-only is exactly the two owned files above.
- Total numstat is `392 <= 400`; the provider is 114 formatted lines and the test is 278 formatted lines.
- BASE..HEAD foundation module/test diff is empty.
- Implementation worktree status after all post-commit gates: clean.

## Concerns

No task blocker remains. The immutable sizing gate has only 8 lines of margin, so later changes must not add 03a cases or weaken an existing oracle; anchor-driven dynamic coverage remains owned by 03a1.
