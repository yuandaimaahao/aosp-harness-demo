# Task 1 evidence-only incremental review (r3)

## Conclusion: PASS

This supersedes r2's prototype-provenance finding: r2 incorrectly bound the assurance input to the upstream historical `04` prototype. The authorized `04a` absolute prototype is present and matches the newly source-verified green evidence exactly. No matrix was rerun and no implementation file was modified.

## Evidence and identity checks

- Authorized `04a` prototype: `/tmp/aosp-harness-publish-04-main.AGaEae/.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-04-04a-runtime-resource-lease-assurance/prototypes/tests/test-resource-leases-assurance.sh` is exactly 396 lines, 24,945 B, SHA-256 `0bf21e8f9d29e5a87cdcc8e962ede20143ccbf49fcb742756923f519b327690b`.
- `task-1-green-command.log` identifies that exact source path, records the identical SHA/bytes/lines for its copied assurance file, and records source-to-copy `cmp` rc 0. It likewise records the provider, docs, and base-test source/copy paths, hashes, sizes, line counts, and each source-to-copy `cmp` rc 0.
- The command log records rc 0, exact 38-B stdout and zero-B stderr, the monotonic/final-flock oracle PASS, plus absent-before and absent-after temporary-tree checks. Its named temporary path is absent now.
- Raw green streams verify independently: `green.out` is 38 B and byte-exactly `RESULT PASS  resource lease assurance\n` (SHA-256 `0efd…0855`); `green.err` is 0 B (empty-file SHA). `red`, `static`, all green artifacts, and their SHA/byte metadata agree with `task-1-package.tsv`; the amended report accurately describes the source-verified run.
- Worktree HEAD remains clean at `3ab44a5430d9038d20ec143ebe2c0846349f584e`; provider parent-to-HEAD numstat remains exact `2/2`.

## Specification compliance

| Requirement | Result | Review evidence |
|---|---|---|
| R1 | ✅ | The unchanged commit modifies exactly the provider with `2/2` churn and the prescribed two-line split; public API, state-format, seam, docs, and base-test remain outside the commit. |
| R2 | ✅ | The source still sends a post-scan reached deadline through `continue`, which returns to the loop-head `flock` before `sleep`. The existing acquired-lock deadline guard remains before recovery, record reads/stale cleanup, and publication; `wait=0` and no-contention control paths are unchanged. The correctly sourced green assurance records its deterministic final-attempt/flock-count oracle as PASS. |

No `EvidenceRecord` exists in the project context; R1/R2 are assessed against the requirements/design/brief rather than invented E-IDs.

## Quality

- YAGNI / duplication: ✅ The implementation remains the required minimal two-line control-flow change.
- Error-path ordering: ✅ Unlock remains in the enclosing `finally` before retry, while an acquired final lock is deadline-rejected before recover/read/publish.
- Verification quality: ✅ The raw stream byte checks, artifact hashes, authorized prototype source/copy identity, all-four-input cmp records, temp lifecycle records, and clean immutable commit identity now make the reported green run auditable without replaying the full matrix.

## Findings

| Severity | Finding | Minimum fix |
|---|---|---|
| B | None | — |
| I | None | — |
| M | None | — |
