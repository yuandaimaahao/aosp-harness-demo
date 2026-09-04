# Task 1.2 independent diff review (r1)

Verdict: PASS

Findings: blocking 0 / important 0 / minor 0 (B/I/M = 0/0/0)

Review scope: `569bb221aca20451706b0a6399683a71255bd7d1..c226a238189fda96e7130cf5cedc9e1bdbe6f8fa`, implementation worktree only; no source, implementation worktree, or commit was modified.

## 1. Specification compliance

R8: ✅ The document contains both exact public signatures; the three TSV columns and all four legal domain/mode pairs; the `android-instance-id` key distinction from ADB serial/CVD name; explicit and default state-root selection with absolute, real, EUID-owned `0700` conditions; logical-owner, PID-reuse, and command-substitution semantics; C-order normalization and SHA-256; cross-owner same/different-mode exclusivity and complete-reentry rule; atomic bundle visibility; monotonic bounded waiting and final no-sleep attempt; stale-owner recovery; release unpublish/tombstone cleanup behavior; and fixed `0|2|3` stdout/stderr outcomes.

The document is byte-identical to the approved prototype at `specs/2026-09-04-04-runtime-resource-leases/prototypes/docs/resource-leases.md` and has exactly 7 lines. The wording is consistent with the provider's owner, normalization, state-root, bundle, stale, release, and public framing behavior; no requirement/provider semantic conflict or misleading claim was found.

## 2. Quality

- YAGNI: BASE..HEAD changes exactly one requested path, `docs/resource-leases.md`; no unrelated files or mechanisms were added.
- Verification: the documented checks are substantive presence/cmp/line-count/diff/clean assertions, not vacuous runs. Independent rerun passed 28 assertions, including all brief protocol checks.
- Prototype drift/copy blocks: none; `cmp -s` and SHA-256 both match.
- Error-path documentation: fixed operation-failure and unavailable streams/return codes, release cleanup failure, contention, timeout, and stale recovery are covered.

## Evidence

- `cmp -s` actual document vs approved prototype: rc 0; both SHA-256 `f16ea8af762fc9dfc65b5d8e96c9c42db9b9253a1c64aae5703a6cc3f5963dea`.
- `wc -l`: 7.
- BASE has no `docs/resource-leases.md` tree entry (`git cat-file -e BASE:docs/resource-leases.md` fails), corroborating genuine RED; saved RED evidence records `test_absent rc=0` and `cmp_missing rc=2`.
- BASE..HEAD name-only: `docs/resource-leases.md`; numstat: `7 0 docs/resource-leases.md`; `git diff --check`: rc 0.
- Implementation worktree `git status --porcelain`: empty.

Conclusion: PASS; no repair or re-review is required.
