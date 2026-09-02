# 03a2 design v5.6 round 1 review

Reviewer: `review_design_03a_r1`

Verdict: **NEEDS_CHANGES** — blocker 0 / important 1 / minor 1

## Review basis

- `specs/2026-09-02-03a2-session-path-race-matrix/{requirements.md,design.md}`
- PLAN v5.6 03a/03a1/03a2/03b dependency, owner, rollback and order sections
- accepted 03a provider and 03a1 private driver plus their ledgers
- `work/2026-09-02-03a2-session-path-race-matrix/{sizing-report.md,evidence.log,run-sizing.sh}` and the 137-line executable entrypoint
- spec skill `references/04-design.md`

The extended sizing controller was independently rerun with shfmt `v3.14.0` and ShellCheck `0.11.0`. It passed dependency-present 37/37, exact `protocol,run-matrix` calls, matrix-before-inert self-disproof, 18 anchor/downstream combinations, driver damage, inert states, fixed tools, exact1/137, full/depth-1, rollback and repository-integrity gates. Thus the findings below are design-document consistency issues, not evidence that the one-file boundary or 400-line budget is infeasible.

## Findings

### Important 1 — overview assigns all damage fixtures to a recursive child and describes a skip seam that neither the component design nor prototype has

Evidence:

- `design.md:7` says all damaged combinations are tested by recursive child fixtures and that a private environment flag makes the child skip the fixture suite to avoid recursion.
- `design.md:68` and `design.md:92-94` instead correctly assign only the matrix-duplicate self-disproof to the production entrypoint; every other provider/driver/core damage combination belongs to a controller-owned isolated fixture table outside the implementation diff.
- The executable prototype confirms the latter architecture: `test-session-path-races.sh:64-75` recursively runs only a `HARNESS_TEST_MATRIX_DAMAGE` child, which terminates at the damaged matrix gate. That variable damages the matrix; it is not a “skip fixture suite” seam. `run-sizing.sh:99-182` owns the remaining damage/inert matrix externally.
- The data-flow participant at `design.md:126` also says plural “recursive child fixtures”, reinforcing the incorrect overview rather than the implemented singular matrix-damage child.

Why this matters: this is the exact production-entrypoint versus controller-fixture ownership boundary the design must freeze. An implementer following the overview could embed the entire damage suite or invent a second skip environment seam, causing scope/line growth and weakening the stated “test-only env, no API” contract.

Required fix:

- Rewrite `design.md:7` to state that the entrypoint recursively runs only the matrix-duplicate self-disproof; the damaged child fails at matrix validation before it can recurse.
- State in the same decision that all other provider/driver/foundation/core damage combinations are controller-owned isolated acceptance fixtures and were deliberately not embedded in the default entrypoint.
- Rename the sequence participant at `design.md:126` to singular `matrix-damage child` (or equivalent). Do not introduce a new skip-fixture environment variable; `HARNESS_TEST_MATRIX_DAMAGE` remains only a fail-closed test mutation, not an API/capability.

### Minor 1 — error-handling section omits the mandated recovery/validation/log/user-visible fields

Evidence:

- The spec design rubric requires the error table columns `错误场景 | 恢复策略 | 校验位置 | 日志 | 用户可见`.
- `design.md:143-154` instead uses `场景 | 分类 | rc / 双流 | 副作用`. Most fail-closed rows say only “无PASS”, so the section itself does not identify where the failure is validated, whether cleanup/termination is the recovery action, or what stderr/user-visible diagnostic policy applies. Some of that information is scattered through the classifier and prototype, but the required error contract is not complete in its designated section.

Required fix: reshape the table to the mandated five fields. Preserve current behavior: fail immediately and clean only the owned temp root; identify matrix/provider/driver/core/adapter/controller as the validation location; successful inert has empty stderr and the fixed PASS; fail-closed has no PASS and a `FAIL ...` stderr diagnostic; controller-gate failures do not start 03b. This should be a documentation-only change.

## Passed checks

- All nine required sections are present in order: the eight design sections plus file list. No TBD/TODO placeholder was found.
- Requirement mapping covers R1 through R10 with no orphan requirement.
- Consumer and producer strings each occur once and are byte-for-byte identical to requirements frontmatter.
- Architecture after the overview correctly keeps the entrypoint to one driver `protocol` plus one `run-matrix`; driver `self-test` is controller-only. The shell does not import/copy the private executor, signature/delta oracle or 14 self-disproofs.
- Matrix generation/order/count checks occur before provider/driver/core classification. CASE_LOG is compared byte-for-byte with TSV IDs and revalidated after driver execution. Driver stdout/stderr are independently captured and checked with exact LF-bearing expected files.
- Provider/driver/core priority matches R4-R7: provider absent inert; present provider anchors before downstream state; driver absent inert but symlink/nonregular/protocol/execute damage fail closed; flag/foundation/core may inert only after healthy provider/driver protocol.
- `HARNESS_TEST_MATRIX_DAMAGE` is otherwise correctly classified at `design.md:68` as test-only, unset in normal calls, fail-closed when externally set, and not a runtime API/capability.
- Full/depth-1, pinned tool versions and exact argv, dependency SHA stability, rollback, exact1/400, manifest/order gate and 03b absence are represented in test strategy and supported by executable evidence.
- File list contains exactly `tests/test-session-path-races.sh`; controller fixtures, prototype/evidence/review assets, accepted 03/03a/03a1 files and future 03b files are explicitly excluded from the implementation diff.
- Mechanical checks passed: frontmatter equality, R1-R10 set equality, nine heading sequence, balanced three Mermaid blocks, `bash -n`, 137 physical lines, and `git diff --check` on the reviewed artifacts.

## Conclusion

The behavior and 137/400 one-file architecture are credible, but Gate ③ should not pass while the overview contradicts the component/prototype ownership of recursive versus controller fixtures. Correct that important inconsistency and normalize the error table, then request a focused round-2 review.
