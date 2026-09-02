# Task 3.2 fresh independent R3 review

Verdict: **PASS**

Scope: immutable cumulative package and Git range `8c55b7bc83183b69a01ed30bb54151e17b1516ad..8d27769692481fc76919ce0f5ea6d7f8c5840479`, task brief, R1/R2 reviews, and latest implementation report. Review was read-only with respect to the implementation, live ledger, and formal delivery merge/refs. All ledger exercises used temporary files; rollback used a dangling synthetic merge and isolated temporary worktrees.

## Blocker

None.

## Important

None.

## Minor

None.

## Reopened gate ⑤ finding

**Closed.** The R2-to-current delta is the necessary one-line wrapper change accepting the parser's exact `PASS ledger-candidate accepted SHA` result as well as `active`. This is not an unsafe string-only relaxation: `ledger_candidate()` remains the sole producer, uses anchored `re.fullmatch`, explicit non-`assert` validation, same-SHA ordered transitions, and requires one terminal active or accepted candidate.

Independent probes used synthetic exact two-parent merge `ac7c95cb0ec4ee5dad9adadc98f8110b231c6421`, with parents `c959efaf9887808621852aff28073cf1f8789ca7` (00a frozen base) and `8d27769692481fc76919ce0f5ea6d7f8c5840479` (reviewed tip). Both temporary histories below ran the complete rollback route and returned exit 0, exact `RESULT PASS seed-contract-runtime\n`, and empty stderr:

- terminal `active` candidate;
- the same candidate transitioned `active -> accepted`.

Each run exercised descendant recovery-wrapper commit, `git revert -m 1`, retained regular executable wrapper, exact `RUNTIME_UNAVAILABLE`, disappearance of dispatcher/marker/module/verify-seed, and all three old harness oracles. The worktree registry was byte-for-byte unchanged after both runs and the dedicated temporary root had no leaked child worktree.

Normal Python and `python3 -O` both accepted exact active, accepted, and valid superseded-to-new-active histories. Both modes rejected with nonzero exit and empty channels: zero candidate, superseded-only, simultaneous multiple candidates, prose/noise containing `delivery-candidate`, wrong-SHA accept, wrong-SHA supersede, activity after acceptance, and an otherwise valid line with a trailing suffix. The rollback wrapper translated every invalid temporary ledger to nonzero exit, empty stdout, and exact `ROLLBACK ERROR active delivery candidate unavailable\n`.

## R1 finding closure

- **B1 remains closed:** exact grammar, transition/cardinality checks, and optimized-Python fail-closed behavior passed the matrix above.
- **I1 remains closed:** main and `digest-immutability` rejected fake Python children that exited zero with no PASS output, emitted stderr, or emitted the expected PASS stream plus an extra blank line. The real routes compare the complete ordered stdout file and require empty stderr.
- **I2 remains closed:** `digest-immutability` maps to `store-object ref-resolve ref-publish` in exact order.
- **I3 remains closed:** a PATH-isolated git wrapper forced pre-registration `worktree add` failure. The route returned nonzero, empty stdout, exact `RESULT FAIL seed-contract-runtime\n`, left its dedicated `TMPDIR` empty, and left the worktree registry unchanged.
- **I4 remains closed:** the oracle requires `-f`, `! -L`, and `-x`; disappearance requires both `! -e` and `! -L`; channels are file-compared with `cmp`. Both full rollback runs passed these predicates and the exact old-three channels.

## Complete task 3.2 acceptance

- Direct Python acceptance produced the exact ordered nine PASS lines with empty stderr.
- Main, `cli`, and all four named routes returned exit 0, exact `RESULT PASS seed-contract-runtime\n`, and empty stderr.
- `test-harness.sh`, parity, and dev-sidebar demo passed their specified final/full stdout oracle with empty stderr.
- The cumulative task diff changes exactly the two authorized files and is 44 additions / 6 deletions; the task additions ceiling is 45. The complete 00a `common` diff is 631 additions, below 730. The latest report is 8 lines, below 140.
- `git diff --check` passed. The implementation worktree and temporary worktree registry were clean after review.
- No AOSP envsetup, lunch, build, sync, fetch, clone, download, or real-source command ran.

## Standards axis

PASS: no documented-standard violation or actionable baseline smell found. The prior dense single-letter rollback output names are gone; the current task delta is narrowly scoped to the accepted terminal state required by the delivery lifecycle.

## Spec axis

PASS: no missing, partial, incorrect, or out-of-scope task-3.2 behavior found. The accepted-state rerun, all fail-closed ledger cases, exact channels, cleanup, rollback topology, named routes, two-file scope, and line ceilings pass.

Axis summary: Standards 0 findings; Spec 0 findings.
