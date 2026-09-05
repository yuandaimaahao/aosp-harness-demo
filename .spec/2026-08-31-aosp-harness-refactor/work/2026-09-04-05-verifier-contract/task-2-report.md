# task-2 report: install canonical verifier provider

## status

DONE

## base

354d8101648060107b3e0bc87708a10a724db201 (`test(harness): add verifier base contract`)

## files

- `common/.harness/bin/verify-sidebar.sh` (new, copied byte-for-byte from the approved prototype; 202 lines, mode 100755)

## commands and results

- Red phase: `cmp -s common/.harness/bin/verify-sidebar.sh .spec/2026-08-31-aosp-harness-refactor/specs/2026-09-04-05-verifier-contract/prototypes/common/.harness/bin/verify-sidebar.sh` while the target was absent → rc 2; target was absent. Evidence: `/tmp/aosp-harness-publish-04-main.AGaEae/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/evidence/task-2-red.txt`.
- 红阶段证据: `/tmp/aosp-harness-publish-04-main.AGaEae/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/evidence/task-2-red.txt`
- Prototype parity: `cmp -s` → rc 0; `wc -l` → 202; mode → 755; SHA-256 for target and prototype is `56f696401ccf53db4c81aa47bcce1d61081639eace5cdba983aecf8af396500d`.
- Fixed shfmt: `/tmp/aosp-harness-tools-04/shfmt --version` → `v3.14.0`; `/tmp/aosp-harness-tools-04/shfmt -d -i 2 -ci -bn common/.harness/bin/verify-sidebar.sh` → rc 0 with no diff.
- Fixed ShellCheck: `/tmp/aosp-harness-tools-04/shellcheck --version` → version `0.11.0`; `/tmp/aosp-harness-tools-04/shellcheck -x --severity=warning common/.harness/bin/verify-sidebar.sh` → rc 0 with no diagnostics.
- Syntax: `bash -n common/.harness/bin/verify-sidebar.sh` → rc 0.
- Base contract: `bash tests/test-verifier-contract.sh` → rc 0, stderr empty, stdout exactly `RESULT PASS  verifier contract` followed by LF.
- `git diff --check` → rc 0.

## scope

Only `common/.harness/bin/verify-sidebar.sh` was added to the worktree. No ledger, review-manifest, STATE, docs, tests, old verifier, or original user worktree files were modified.

## commit and independent review

- Commit: `75221708be3f365663d7d8c00e73c57a761f41c2` (`feat(harness): add canonical verifier provider`).
- `git diff 354d8101648060107b3e0bc87708a10a724db201..HEAD --name-only` is exactly `common/.harness/bin/verify-sidebar.sh`; numstat is `202 0`; `git diff --check` passes; post-commit worktree is clean; the file remains byte-identical to the approved prototype.

## test summary

Canonical provider installation checks completed: red absence evidence, prototype parity, fixed shfmt v3.14.0, fixed ShellCheck 0.11.0 warning-level, bash syntax, diff-check, and the base contract’s exact PASS output.
