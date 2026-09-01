# Task 4 fix round 1 report

## Status

BLOCKED — return to PLAN. The three review findings have a behaviorally green candidate, but applying the required shfmt result makes the fixed execution diff `527 > 400`; no implementation commit was made.

## Commits

- None. Task base remains `fad7bf384d9d8807f1f268649bc8ed19e10cf4b0`.

## Red evidence

- `task-4-fix1-red-foundation.log`: a fixture containing the real provider but genuinely no foundation made both default and `--dependency-absent` exit `1` before entering the inert source case.
- `task-4-fix1-red-static.log`: pinned ShellCheck 0.11.0 reproduced SC2034/SC2053; pinned shfmt 3.14.0 produced a non-empty diff.
- `task-4-fix1-red-stream.log`: an extra trailing LF still compared equal through command substitution.

## Candidate verification

The uncommitted candidate was tested before being discarded. It globally required only the provider, routed a genuinely absent foundation from both default and `--dependency-absent` to the all-missing inert case, kept the normal default dispatcher to exactly `source-validate`, `roots-static`, and `mutations`, removed SC2034/SC2053, and compared child stdout with `cmp` against a file containing exactly `SUMMARY\n`.

- `bash ./tests/test-session-path.sh`: PASS.
- `bash ./tests/test-session-path.sh --dependency-absent`: PASS.
- Genuinely foundation-absent default and flag fixtures: both rc `0`, exact summary stdout, empty stderr.
- `bash ./tests/test-session-state-foundation.sh`: PASS.
- `bash ./scripts/check.sh --offline`: PASS.
- `git diff --check`: PASS.
- `/tmp/aosp-gate-review.T8RDQ1/shellcheck/shellcheck -x -e SC2015,SC2016 tests/test-session-path.sh`: PASS.
- `/tmp/aosp-gate-review.T8RDQ1/shfmt -d -i 2 -ci -bn tests/test-session-path.sh`: correctly FAILS because the file is not formatted.

## Exact2 / 400 blocker

- Current task base: provider `114` + test `283` = `397` lines.
- Applying pinned `shfmt -w -i 2 -ci -bn` to the fixed candidate: provider `114` + test `413` = `527` lines.
- The required format result exceeds the immutable limit by `127` lines. Eliminating that much is a roughly 31% rewrite of the test, not a shared-helper compression local to the three review findings. Formatter-ignore directives or deleting oracle/comment content would only bypass the contract and were not used.
- Foundation production/test diff remains empty. No 03a1 behavior, public API, or project/session mutation was added.

## Concern

PLAN must reconcile the exact2 `<=400` gate with requiring the entire new test file to be shfmt-clean, either by allocating another owned test slice/file or revising the size boundary before execution resumes.
