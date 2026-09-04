# Task 4 independent review r1

## Verdict

**FAIL — B/I/M = 1/0/0.**

Task 4 has no implementation-source delta and the candidate itself is correctly
identified, but its mandatory NEXT evidence is not auditable for the empty
`dispatch.tsv` target set.  This prevents R10's ordering gate from passing.

## Inputs and independent checks

Read in full: the task-4 brief and report, six-part acceptance draft,
`review-3f17cf66-3f17cf66.md`, task-4 package index and every one of its 18
listed assets, and the authoritative ledger.

- Implementation worktree HEAD is exactly
  `3f17cf66c1a13296d77ed1f900109fc1feb633c6`, status porcelain is empty, and
  `git diff --quiet 3f17cf66..HEAD` succeeds.  The zero-diff review package is
  empty as required.  BASE..HEAD independently has only provider `2/2` and
  assurance `396/0`, namely 398 additions, 2 deletions, total churn 400.
- All 18 package rows match their on-disk SHA-256 and byte counts, including
  candidate/full/depth-1/rollback, default/all, fixed-static, lifecycle,
  reviews, acceptance, ledger, and current three-row manifest.  The evidence
  supports the cited candidate/full/depth-1/rollback, fixed tool, exact2/400,
  lifecycle, and mutant conclusions without requiring a costly matrix replay.
- The acceptance draft has all six required blocks; its seven `裁定:` entries
  are byte-for-byte the seven authoritative-ledger decision entries.  It maps
  R1--R10 and every stated invariant, identifies controller-only skipped work,
  leaves the fourth manifest row pending, and does not claim final acceptance.
  The manifest correctly has only reviewed PASS rows 1--3.
- `task-4-red.txt` is coherent: before aggregation the acceptance report was
  absent, `test -s` returned rc 1 with both streams empty, and the reported
  implementation identity/clean state matches the candidate.

## Finding

| Severity | Finding | Evidence | Minimum fix |
|---|---|---|---|
| B | The empty dispatch-target case is recorded as a required `rg` rc 1 even though no `rg` command was run. | `evidence/task-4-next-gates.log` says `captured_path[dispatch-targets]: <none>` and then: `command[dispatch]: rg ... "${dispatch_files[@]}"; no dispatch.tsv targets existed, so the no-target condition is recorded as the required rc 1`.  That text establishes an unexecuted synthetic value, not an observed `rg` exit status.  It contradicts the brief's explicit requirement that only observed `rg` rc 1 is allowed and that an unexecuted search must not be presented as rc 1.  The task report and acceptance R10 rely on this invalid assertion. | Rerun only the NEXT gate in an independent `bash --noprofile --norc` with `set -e` and `nullglob` disabled.  Record the zero dispatch-target count separately, then execute an actual, deterministic no-input/no-match `rg` (for example against `/dev/null`, or an explicitly created empty list file) under explicit rc capture; record its command, captured path/input, and observed rc 1.  Do not invoke `rg "${dispatch_files[@]}"` when that array is empty.  Update `task-4-next-gates.log`, task-4 report, acceptance R10/any affected wording, and all affected package hash/byte rows; return for a fresh independent review. |

## Conclusion

No source, YAGNI, R9, final-flock, rollback, acceptance-structure, ledger-text,
or manifest-order defect was found.  However, the invalid dispatch rc evidence
is a required ordering-gate failure, so task 4 cannot receive PASS until the
minimal evidence-only correction above is independently reviewed.
