# PLAN v5.3 review round 2

Status: NEEDS_CHANGES

Findings: blocker 2, important 2, minor 1.

- B1: 03d still shared `tests/COVERAGE.md` with 02, and upstream rollback did not prove automatically discovered downstream tests remained green. Require an owned coverage fragment and present/absent inert test contracts for every module edge.
- B2: partial-provider wording conflicted with foundation's public validate. Define completeness only as marker `1` plus all five public APIs; incomplete consumers ignore any already loaded function.
- I1: PLAN-level manifest contract did not mechanically specify task order, execution BASE, accepted HEAD and adjacency. Use a six-column sequenced manifest.
- I2: private module edges used vague `_core` names without parameter, stream or return contracts. Freeze exact shell signatures and results.
- M1: replace unbounded “module damaged” with source-nonzero or expected-export-missing fixtures.

Mechanical evidence: `check-plan.py` and `git diff --check` passed; findings were semantic gaps outside those checkers.
