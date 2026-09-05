# task-1 report: install verifier base contract test

## status

DONE

## base

65d67b52e5b34d0d9d2add587083ebf2fadcd3ea (`docs(spec): pass verifier contract design and tasks gates`)

## files

- `tests/test-verifier-contract.sh` (new, copied byte-for-byte from the approved prototype; 102 lines, mode 100755)

## commands and results

- Red phase: `bash tests/test-verifier-contract.sh` with the test entry absent → rc 127, stdout empty, no PASS marker; evidence: `/tmp/aosp-harness-publish-04-main.AGaEae/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/evidence/task-1-red.txt`.
- Prototype parity: `cmp -s target prototype` → rc 0; `wc -l` → 102; mode → 755.
- Syntax: `bash -n tests/test-verifier-contract.sh` → rc 0.
- ShellCheck warning gate: `/tmp/aosp-harness-tools-04/shellcheck --version` reports version `0.11.0`; `/tmp/aosp-harness-tools-04/shellcheck -x --severity=warning tests/test-verifier-contract.sh` → rc 0 with no diagnostics.
- `git diff --check` → rc 0.
- Provider-absent post-install check: `bash tests/test-verifier-contract.sh` → rc 1, stdout empty, stderr exactly `FAIL provider`, no PASS marker. This is the expected task-1 state because task 2 supplies the provider.
- Fixed shfmt gate: `/tmp/aosp-harness-tools-04/shfmt --version` reports `v3.14.0`; `/tmp/aosp-harness-tools-04/shfmt -d -i 2 -ci -bn tests/test-verifier-contract.sh` → rc 0 with no diff.

## scope

Only `tests/test-verifier-contract.sh` was added to the worktree. No ledger, review-manifest, STATE, or original user worktree files were modified.

## commit and independent review

- Commit: `354d8101648060107b3e0bc87708a10a724db201` (`test(harness): add verifier base contract`).
- `git diff BASE..HEAD --name-only` is exactly `tests/test-verifier-contract.sh`; numstat is `102 0`; `git diff --check` passes; post-commit worktree is clean; target remains byte-identical to the prototype.

红阶段证据: `/tmp/aosp-harness-publish-04-main.AGaEae/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/evidence/task-1-red.txt`

## test summary

Base-test checks completed: red absence, prototype cmp/length/mode, fixed shfmt v3.14.0, fixed ShellCheck 0.11.0 warning-level, bash syntax, diff-check, report checker, and provider-absence fail-closed behavior. Full contract success is deferred until the canonical provider is present.
