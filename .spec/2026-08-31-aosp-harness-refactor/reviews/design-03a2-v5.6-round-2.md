# 03a2 design v5.6 round 2 review

Reviewer: `review_design_03a_r1`

Verdict: **PASS** — blocker 0 / important 0 / minor 0

## Review scope

- `specs/2026-09-02-03a2-session-path-race-matrix/{requirements.md,design.md}`
- `reviews/design-03a2-v5.6-round-1.md`
- `work/2026-09-02-03a2-session-path-race-matrix/{sizing-report.md,evidence.log,run-sizing.sh}` and the 137-line executable prototype
- spec skill `references/04-design.md`

## Round-1 closure

### I1 — recursive child versus controller fixture ownership: closed

- `design.md:7` now states that the production entrypoint recursively self-disproves only matrix duplicate in a provider-absent child. All other provider/driver/core damage combinations are replayed by the `.spec` controller in isolated candidate roots.
- The same line explicitly forbids a new skip-fixture environment seam. This matches `design.md:68`: `HARNESS_TEST_MATRIX_DAMAGE` only corrupts the child matrix and is not a runtime API/capability.
- `design.md:92-94` retains the external controller fixture table as acceptance evidence outside the implementation diff.
- The sequence participant at `design.md:126` is now the singular `recursive matrix-damage child`.
- These statements match the executable prototype: `test-session-path-races.sh:64-75` owns only the duplicate-row recursive proof; `run-sizing.sh:99-182` owns the remaining damage/inert combinations. The damaged child terminates at matrix validation before recursion, so no skip mechanism is needed.

### M1 — strict error-handling table: closed

- `design.md:145-154` now uses the required exact five columns: `错误场景 | 恢复策略 | 校验位置 | 日志 | 用户可见`.
- Every relevant class names its fail-closed/inert/controller recovery, validation boundary, stderr/evidence policy and observable rc/summary behavior.
- The entries remain consistent with requirements and prototype: successful inert is rc0 with only the fixed summary and no stderr; fail-closed paths emit no PASS and a stderr `FAIL` diagnostic; acceptance failures retain `.spec` evidence and do not start 03b.

## Regression review

- No new ownership or dependency ambiguity was introduced. The entrypoint still invokes driver `protocol` and `run-matrix` only; controller-only self-test and damage fixtures remain outside production.
- Provider/anchor/driver/foundation/core priority is unchanged and matches R4-R7. Matrix validation/self-disproof remains before any inert classification.
- Exact driver stdout/stderr capture, CASE_LOG-to-TSV byte comparison and post-run 37/unique/category gates are unchanged.
- `HARNESS_TEST_MATRIX_DAMAGE` remains a test-only fail-closed mutation, not an API, capability or skip seam.
- Rollback, full/depth-1, pinned shfmt/ShellCheck, dependency SHA, exact1/400, manifest/order and 03b absence gates remain intact.
- File ownership remains exact one implementation file, `tests/test-session-path-races.sh`; controller fixtures and all `.spec` evidence remain acceptance assets only.

## Mechanical checks

- Nine sections remain present in order; no placeholder was found.
- R1-R10 mapping is complete.
- Consumer and producer strings each match requirements frontmatter byte-for-byte exactly once.
- The strict error-table header occurs exactly once.
- Three Mermaid blocks remain balanced; the sequence role agrees with the component boundary.
- Prototype remains 137 physical lines and passes `bash -n`; round-1 independent full sizing execution already passed fixed tools, exact1/137, full/depth-1 and rollback.
- `git diff --check` passes for requirements/design.

## Conclusion

Both round-1 findings are fully closed and no new issue was found. The design is ready to pass Gate ③ and proceed to task decomposition under the existing autopilot authorization.
