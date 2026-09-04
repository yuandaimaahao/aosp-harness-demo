# Task 4 aggregation report — runtime resource lease assurance

Status: DONE_WITH_CONCERNS (pre-review evidence aggregation only; no source delta).

## Identity and red / NEXT evidence

- Implementation is clean at `3f17cf66c1a13296d77ed1f900109fc1feb633c6` (`git status --porcelain` is empty); it remains the supplied accepted candidate.
- The required red precondition is recorded in [task-4-red.txt](evidence/task-4-red.txt): missing `acceptance/acceptance-report.md` caused `test -s` to return rc 1 with both streams empty.
- [task-4-next-gates.log](evidence/task-4-next-gates.log) records an independent `set -e`, nullglob-disabled Bash check. The date-prefixed 05 spec directory, `spec/*-05-verifier-contract` branch, and 05 worktree are absent; ledger and execution-base searches observed rc 1 no-match. The separately recorded zero `dispatch.tsv` target count is followed by an actual deterministic `rg` against non-symlink, zero-byte character device `/dev/null`, captured under temporary errexit disable as observed rc 1 before `set -e` is restored. No 05/06/08 asset was created.

## Upstream evidence synthesis

| Area | Result | Auditable source |
|---|---|---|
| Candidate | default assurance and offline rc 0; exact 38-byte summary / empty stderr; offline discovery exactly one | `evidence/task-3-candidate-offline.log` |
| Full history | `git clone --no-local`, HEAD accepted, exact2/400, default/offline rc 0, clean | `evidence/task-3-full.log` |
| Depth 1 | real `file://` clone, HEAD accepted, count 1, nonempty 41-byte shallow marker; prototype/hash/blob substitute for unavailable BASE; default/offline rc 0, clean | `evidence/task-3-depth1.log` |
| Rollback | isolated temporary inverse restored BASE provider and removed assurance; base lease, 03e lifecycle, and offline rc 0; assurance discovery 0; branch/tree removed | `evidence/task-3-rollback.log` |
| CLI / absent | default and `all` are active rc 0 with exact summary and empty stderr; absent has three inert surfaces with the same summary; invalid/damaged routes are fail closed | task-2 report, static and raw stream evidence |
| Fixed tools | shfmt v3.14.0, ShellCheck 0.11.0 warning threshold, and bash -n pass for both delivery files | task-3 candidate log; task-2 static log |
| Lifecycle faults | fake mktemp and fake rm each rc 1, stdout empty, dedicated 28-byte stderr, no PASS | `evidence/task-2-lifecycle-faults.log` |
| Four mutants | overlap, real unpublish, bundle normalization, and fake-adapter fixture each self-proves using its exclusive failing label and suppressed PASS | task-2 report and `task-2-review-r1.md` |
| Exact boundary | BASE..HEAD names only provider `2/2` and assurance `396/0`; 398 additions + 2 deletions = 400; docs/base test unchanged; diff-check clean | task-3 candidate/full logs and task-3 review |

The pre-existing controller manifest has exactly the three independently reviewed PASS rows for tasks 1–3. This task deliberately does not alter it: its fourth row and the final rerun are controller-only after independent task-4 review.

## Review inputs read

Read-only inputs included task-1/2/3 reports; their raw evidence packages and package indexes; task-1 r1–r3, task-2 r1, and task-3 r1 independent reviews; task-4 r1; controller review packages; the authoritative 04a ledger; and the existing three-row manifest. Tasks 1–3 reviews are PASS after task-1's provenance correction (r3), task-2's source/evidence review, and task-3's checkout/rollback review. Task-4 r1's sole B1 was the former synthetic dispatch rc; this report records its minimal observed-rc correction and remains pending a new independent review.

## Handoff

Use [acceptance-report.md](acceptance/acceptance-report.md) as the six-part closeout draft and [task-4-package.tsv](evidence/task-4-package.tsv) as its artifact index. Controller-only remaining actions: independent review of this aggregation, manifest row 4, ledger/task/workflow updates, and final mechanical rerun. No final acceptance is asserted here.
