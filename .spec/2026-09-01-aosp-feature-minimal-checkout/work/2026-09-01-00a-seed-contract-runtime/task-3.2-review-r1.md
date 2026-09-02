# Task 3.2 fresh R1 review

Verdict: **FAIL**

Scope: immutable cumulative package `8c55b7bc83183b69a01ed30bb54151e17b1516ad..2a15daed0f449a7a40c597588d2bbdda78b86593` (commit `2a15dae`), task brief, implementation report, and `task-3.2-red.txt`. Review was read-only with respect to implementation and live ledger; rollback was exercised only with a temporary ledger and a dangling synthetic two-parent merge.

## Blocker

### B1 — ledger candidate selection is not fail-closed

`common/tests/test_seed_contract_runtime.py:212-217` treats every line containing `delivery-candidate` as candidate material, then uses an unanchored suffix `re.search`; all grammar, transition, cardinality, and final-state checks are Python `assert`s.

This violates brief lines 654/700 (zero active must fail closed, and supersession must be folded by SHA/order) and lines 429/696 (rollback must use the unique exact ledger merge SHA):

- A temporary ledger containing only `- note example, not an event: delivery-candidate sha=aaaa… status=active` returned exit 0 and `PASS ledger-candidate active aaaa…`; arbitrary ledger prose is therefore selectable as an event.
- With two different active records, normal Python failed, but `python3 -O ... ledger-candidate --ledger TEMP` returned exit 0 and selected the second SHA. `PYTHONOPTIMIZE` therefore disables the fail-closed gate.
- `test-seed-contract-runtime.sh:13-16` trusts this output and checks only that the selected object has two parents, so a noise-selected merge can drive the rollback oracle.

Required direction: parse only the ledger's exact event-line grammar, use explicit unconditional validation (not `assert`), fold active/superseded/accepted transitions by identical SHA and append order, and require exactly one terminal active or accepted candidate.

## Important

### I1 — main and named acceptance routes can false-pass without their exact PASS channels

Brief lines 167, 660/706, and 705 require exact child channels and the ordered nine PASS lines. `common/tests/test-seed-contract-runtime.sh:31` merges stderr into stdout with `2>&1`, checks only exit status, then discards `output` on success.

An isolated PATH probe replacing `python3` with a program that emitted `unexpected stderr` and exited 0 made both the default route and `--case digest-immutability` return exit 0, exact `RESULT PASS seed-contract-runtime\n`, and empty stderr. Thus zero PASS lines, missing cases, reordered output, or child stderr noise are hidden by the acceptance entry.

### I2 — `digest-immutability` omits a load-bearing immutability test

`common/tests/test-seed-contract-runtime.sh:29` maps the route only to `store-object ref-publish`. Brief line 180 covers validation/collision failures against existing object/ref/sentinel bytes. `ref_resolve()` at `common/tests/test_seed_contract_runtime.py:153-162` is the test that snapshots the tree around resolver validation, corrupt-ref/object, closure, lock, and public-gate failures. Omitting `ref-resolve` means the named invariant does not aggregate all tests that carry its stated validation/ref immutability property.

### I3 — a pre-registration rollback failure leaks the `mktemp` directory

At `common/tests/test-seed-contract-runtime.sh:17-19`, `cleanup` succeeds only if `git worktree remove` succeeds. If `mktemp -d` succeeds but `git worktree add` fails before registration, `worktree remove` fails and the empty temp directory is never removed.

An isolated git-wrapper probe forcing only `worktree add` to fail produced exit 1 / `RESULT FAIL seed-contract-runtime\n` and left the recorded `/tmp/tmp.*` directory present (removed after the probe). Cleanup needs a safe fallback for an unregistered exact temp path while still verifying worktree metadata removal.

### I4 — rollback type/disappearance/channel oracles are weaker than R16

Brief line 429 requires a retained **regular executable**, four paths truly absent, and exact `RUNTIME_UNAVAILABLE`. At `common/tests/test-seed-contract-runtime.sh:22-25`:

- `-x "$fixture"` does not establish regular/non-symlink type;
- `! -e PATH` treats a dangling symlink as absent;
- command substitutions for `err`, parity, and the other outputs strip all trailing newlines, so extra trailing blank lines pass an oracle stated as exact.

The synthetic happy-path rollback did pass, but these predicates can accept the wrong filesystem type or non-exact channels.

## Minor / Standards

No documented-standard hard violation was found. As a readability judgement call (possible Mysterious Name), `common/tests/test-seed-contract-runtime.sh:24-25` uses `h`, `p`, and `s` for three distinct regression outputs, making a dense failure predicate unnecessarily hard to audit.

## Passing evidence

- Frozen package matches the Git diff; exactly the two authorized source files changed.
- Diff is 38 additions / 6 deletions; task addition ceiling 45 is met; `git diff --check` passes.
- `task-3.2-red.txt` exists and records exit 1, empty stdout, and exact `ROLLBACK ERROR active delivery candidate unavailable` against the live ledger. Re-running it produced the same channels; live ledger was not modified.
- The direct nine-case command produced the exact ordered nine PASS lines with empty stderr.
- Default acceptance and all four named routes produced exit 0, exact one-line stdout, and empty stderr on the current implementation.
- A temporary two-parent merge based on frozen base `c959efaf...` and task tip `2a15daed...` exercised the full rollback happy path: exit 0, exact result line, empty stderr, and unchanged worktree registry afterward.
- The three old harness commands passed with their required outputs.

## Axis summary

- Standards: 0 hard findings, 1 minor judgement call; worst is compressed rollback-oracle naming.
- Spec: 1 blocker, 4 important findings; worst is ledger candidate selection accepting noise and losing all cardinality/transition checks under optimized Python.
