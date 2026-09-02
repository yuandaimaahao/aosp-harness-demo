# 03a2 Task 1 fix independent re-review

## Verdict

**PASS** — Blocker: 0, Important: 0, Minor: 0.

Reviewed cumulative range: `6f26119e0f49891f033c1f63183a27344cf60bb5..8ef44f1b59e67c02dacc695b2eef0c2b6fc87a9a`.

## Standards axis

PASS. No documented-standard violation or reportable smell was found. The executable mode matches the shebang/test-entrypoint role, and `LC_ALL=C` is narrowly placed to stabilize the locale-sensitive matrix commands and the recursive copied child.

## Spec axis

PASS. The prior Important and Minor findings are both closed, and the cumulative Task 1 behavior remains within scope.

### Prior finding closure

- **I1 closed — executable/direct invocation:** the entrypoint is tracked as mode `100755` (`git diff --summary` reports `create mode 100755`). Direct calls in an isolated provider/foundation/driver-absent root for no arguments, `all`, and `--dependency-absent` each return rc `0`, stderr `0B`, and exact `41B` stdout `RESULT PASS  session path race assurance\n`. This now supports the fixed direct rollback commands in PLAN lines 216–218.
- **M1 closed — C locale:** `tests/test-session-path-races.sh:3` exports `LC_ALL=C` before temporary ownership, matrix construction, and validation. This satisfies design line 66 and Task 1 brief line 143; direct tests launched with caller locale variables unset still return the exact expected result.

## Regression and scope evidence

- The fix commit changes only the tracked mode `100644 -> 100755` and adds `export LC_ALL=C`; no original Task 1 oracle was removed.
- Cumulative implementation diff remains exact one new file: `tests/test-session-path-races.sh`, `95` additions/physical lines (`95/400`). Foundation, provider, and private driver have zero range diff.
- BASE still has the target physically absent. The saved real red is rc `127`, stdout `0B`, no PASS, and the exact missing-file error.
- Provider-absent no-arg, `all`, and `--dependency-absent` direct calls are exact green. Unknown, extra, and flag-with-value forms return rc `1`, stdout `0B`, and no PASS.
- Matrix duplicate damage returns rc `1`, stdout `0B`, and no PASS before inert selection. The canonical 37-row/four-column builder, 37 unique IDs, continuous nine-family counts, and recursive provider/foundation/driver-absent self-disproof remain present.
- With the real provider present, both direct default and `--dependency-absent` calls retain the intentional Task 2 red seam: rc `1`, stdout `0B`, exact `38B` stderr `FAIL dependency classifier incomplete\n`; an exported fake `python3` records zero calls.
- No foundation/driver variables, anchor classifier, driver type/protocol validation, self-test, or run-matrix adapter were added. Task 2 and Task 3 remain unimplemented as required.
- Current foundation/provider/driver SHA-256 values match the red and implementation reports. Pinned shfmt `v3.14.0` with `-d -i 2 -ci -bn`, ShellCheck `0.11.0` with `-x --severity=warning`, `bash -n`, `git diff --check`, exact1/400, dependency zero-diff, and implementation worktree-clean checks all pass.

Task 2 may be dispatched.
