# task-3 report: install verifier contract document

## status

DONE

## base

`65d67b52e5b34d0d9d2add587083ebf2fadcd3ea` (`docs(spec): pass verifier contract design and tasks gates`)

## head

`9e5edb45a3048e4c208e2d7fe135639768cc87db` (`docs(harness): define verifier contract`, amended after review round1)

## files

- `docs/verifier-contract.md` (new, copied byte-for-byte from the approved prototype; 67 lines, mode 100644)

## commands and results

- Red phase: `cmp -s docs/verifier-contract.md .spec/2026-08-31-aosp-harness-refactor/specs/2026-09-04-05-verifier-contract/prototypes/docs/verifier-contract.md` while the target was absent → rc 2; target was absent.
- Prototype parity: final doc and controller prototype `cmp -s` → rc 0; `wc -l` → 67; both SHA-256 `a383c4025971590a2b9afeff24a0310b1f1ffa89086218a691fc61d95fe2a0a2`.
- Review round1 I1 fix: the CLI paragraph now explicitly states that real mode rejects `--allow-skip` and demo mode accepts it; line count remains 67. Controller prototype was synchronized byte-for-byte. Controller `design.md` line 154 doc hash was updated only to the new SHA-256.
- Base contract: `bash ./tests/test-verifier-contract.sh` → rc 0, stdout exactly `RESULT PASS  verifier contract` followed by LF, stderr empty.
- Post-amend three controller-prototype parity checks (provider, document, base test) → all rc 0.
- Exact-three scope: `git diff 65d67b5..HEAD --name-only` is exactly `common/.harness/bin/verify-sidebar.sh`, `docs/verifier-contract.md`, `tests/test-verifier-contract.sh`.
- Churn: `git diff 65d67b5..HEAD --numstat` is `202 0`, `67 0`, `102 0`; added+removed total is 371.
- Independent diff review: task increment is only the new 67-line `docs/verifier-contract.md`; `git diff --check 65d67b5..HEAD` → rc 0.
- Post-amend worktree status → clean.

红阶段证据: `/tmp/aosp-harness-publish-04-main.AGaEae/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/evidence/task-3-red.txt`

## test summary

Ran review-I1 predicate check, controller prototype parity (3), base contract, exact3 name-only, numstat 371, diff-check, report checker, independent diff review, and clean-worktree checks; all passed.

## concerns

None.
