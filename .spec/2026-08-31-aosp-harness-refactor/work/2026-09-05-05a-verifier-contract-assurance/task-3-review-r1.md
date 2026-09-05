# Task 3 independent diff/evidence review — r1

Verdict: **PASS**

Review scope was limited to `task-3-brief.md`, `task-3-report.md`, the empty
`5f867fa8..5f867fa8` review package, and the necessary spot checks in
`evidence/task-3-green.txt` and `acceptance/acceptance-report.md`. No long test
was rerun and no implementation file was changed.

## Findings

### B — blockers

None.

### I — important

None.

### M — minor

- The green evidence records the version probes with the absolute fixed-tool
  paths, but abbreviates the subsequent formatting/lint command labels to
  `shfmt` and `shellcheck`. The report explicitly states that only
  `/home/zzh0838/.cache/aosp-harness-tools-04/bin` was used, and both required
  versions and empty results are recorded, so this does not invalidate the
  result. Future evidence would be slightly stronger if those two command
  labels also retained their absolute paths.
- The dispatch gate records `Dispatch targets found: 0` and then uses checked
  `/dev/null` for a deterministic real `rg` rc1 probe. This correctly avoids
  treating “no input files” as a successful search and records a genuine rc1,
  but the command that produced the zero-target count is not reproduced. The
  explicit result, enclosing gate rc0, and separate per-ID rc1 records are
  sufficient here; retaining that enumeration command would improve audit
  reproducibility.

## R compliance

| Requirement | Result | Evidence/reasoning |
|---|---|---|
| R1 | PASS | Task 3 has an empty `5f867fa8..5f867fa8` source diff. The execution BASE to accepted HEAD delta is exactly one added path, `tests/test-verifier-contract-assurance.sh`, at 331/0, with `diff --check`, `bash -n`, fixed shfmt v3.14.0 and ShellCheck 0.11.0 green. The listed 05 exact3, three old verifiers, session/resource-lease paths, and named 06–10 source targets all have zero diff. |
| R8 | PASS | Task-3 rollback/converge/final-capture roots are repo-external, type/prefix validated, removed with `find ... -delete`, and proved physically absent. The active terminal rerun preserves all three 05 hashes. The assurance lifecycle, 0700 fixture root, cleanup-before-summary guard, self-copy child guard, and four exact first-label mutants are properly consumed from the already reviewed task-1 implementation evidence; task 3 does not duplicate or alter them. |
| R9 | PASS | Candidate mechanics prove exact1=331/0, fixed tools, ancestry, `diff-check`, isolated converge, and clean status. The reviewed task-2 contract supplies candidate/full/true-depth-1 assurance + 05 base + offline as 9/9 rc0 with empty stderr, including the one-commit shallow marker checks and physical cleanup. Review-manifest row 3 is correctly deferred until this review PASS. |
| R10 | PASS | The external rollback removes only TARGET and its committed tree has zero name/numstat diff from execution BASE. Assurance discovery is zero; 05/01/04/04a/03e/offline plus all three old demos are 9/9 rc0 with empty stderr; rollback status is clean and its tree is physically deleted. Both 06 and 09 remain absent across the five prohibited asset categories. The accepted terminal evidence is dependency-present active execution, not inert PASS. |

## E / acceptance compliance

The acceptance checklist is numbered E1–E10 below in its published order.

| Evidence item | Result | Review |
|---|---|---|
| E1 — prototype/final identity, exact1≤400, fixed tools, protected paths | PASS | Prototype identity was closed by the prior task-1 review; task 3 independently preserves the accepted HEAD and records exact1=331/0, fixed-tool checks, and protected-path zero diff. |
| E2 — active/inert/partial/damaged/present-absent routing and CLI closure | PASS (consumed) | This is implementation behavior already covered by the reviewed active task-1/task-2 evidence; task 3 neither changes it nor substitutes inert output. |
| E3 — 264 unique expected/executed IDs | PASS (consumed) | The acceptance draft binds the reviewed 264/264 independent manifest evidence with no missing, duplicate, or extra ID. |
| E4 — runner/direct argv, streams, query, serial and zero-query closure | PASS (consumed) | Bound to the prior reviewed active evidence; no implementation delta exists in task 3. |
| E5 — CLI/serial/runner, query baselines and help/doc/parser sets | PASS (consumed) | Bound to the prior reviewed active evidence; no implementation delta exists in task 3. |
| E6 — grammar, 80 service combinations and byte/newline cases | PASS (consumed) | Bound to the prior reviewed active evidence; no implementation delta exists in task 3. |
| E7 — five details, summary, terminal/rc, modes and fixtures | PASS (consumed) | Bound to the prior reviewed active evidence; acceptance records five details and summary sum 5. |
| E8 — external temp, hashes, guarded cleanup and four mutants | PASS | The implementation portion is consumed from the prior review; task 3 adds direct hash preservation and multiple physically verified cleanup proofs. No PASS is claimed for a cleanup/mutant failure. |
| E9 — candidate/full/depth-1, base/offline, manifest/converge/diff/clean | PASS for the review gate | All executable and mechanical evidence needed before review passes. Row 3 and the final three-row manifest gate are intentionally post-review controller work, so requiring row 3 before issuing this review would create a circular dependency. |
| E10 — rollback zero diff/regressions and 06/09 absence | PASS | Zero-diff rollback, TARGET count zero, nine regressions, clean/physical cleanup, and both IDs’ five-category absence are explicitly recorded. |

## Focused evidence assessment

- **Rollback tree vs execution BASE:** both name-only and numstat outputs are
  zero bytes after the rollback-only commit; `diff --check` is rc0. This is a
  tree-equivalence proof, not merely a claim that TARGET was deleted.
- **Nine rollback regressions:** the exact required set is present: 05, 01, 04,
  04a, 03e, offline, and common/Claude/Codex demos. Each is rc0 with empty
  stderr and the expected terminal PASS line.
- **Physical cleanup:** rollback, converge and final capture roots are validated
  before deletion and subsequently tested absent. The final task-owned audit
  reports zero remaining matching regular files/directories.
- **06/09 NEXT gate:** spec directory, `spec/` branch, worktree, execution BASE,
  and dispatch are all absent for each ID. Expected search misses are recorded
  as rc1; the discarded rc123/rc127 orchestration probes are not presented as
  product evidence and the complete Bash rerun is.
- **Candidate gates:** exact1, 331≤400, fixed versions, syntax/style/lint,
  protected zero diff, ancestry, converge, diff-check, and clean status all
  pass. The dependency-present assurance terminal rerun is rc0 with exact
  stdout and empty stderr; offline finds it exactly once and also passes.
- **Manifest sequencing:** the existing two reviewed rows remain untouched.
  Row 3 must be appended with base=head=`5f867fa8e5d1c5b79001d0ec201045139fa29a40`
  only after this PASS, followed by the three-row continuity checks,
  mark/ledger/sync, active final rerun, and accept. This is a valid acyclic
  sequence; the draft does not falsely claim those controller-owned actions are
  complete.

## Quality assessment

- **YAGNI:** PASS. Task 3 introduces no source or implementation-branch commit;
  the rollback-only commit is isolated and physically discarded. Acceptance
  work remains limited to evidence and controller bookkeeping boundaries.
- **Validation effectiveness:** PASS. The evidence combines tree comparisons,
  exact counts, return codes, stream byte/hash checks, terminal-line oracles,
  before/after hashes, real absence searches, and post-cleanup existence tests.
- **Duplication:** PASS. Repeated summaries in the task report and acceptance
  draft serve different handoff/audit roles; no executable test logic is
  duplicated by task 3.
- **Error paths:** PASS. rc1 is distinguished from rc0 and rc>1, discarded probe
  failures are disclosed, cleanup is guarded, active evidence is distinguished
  from inert PASS, and pending post-review work is not prematurely marked done.

Final decision: **PASS**. The controller may append manifest row 3 and execute
the explicitly pending mark/ledger/sync and post-review terminal gates. This
review does not itself assert final acceptance before those steps succeed.
