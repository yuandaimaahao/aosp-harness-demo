# Task 1.3 review — round 1

Status: NEEDS_CHANGES

Scope reviewed: the supplied task brief, implementer report, and package
`c7ef909b..b814ecfb`. No source files were changed and no implementation
verification was re-run.

## ① Spec compliance

| Requirement / requested check | Verdict | Evidence / assessment |
|---|---|---|
| Three CI tools have missing and wrong-version cases (six total) | ✅ | `tool_cases` has ShellCheck, shfmt, and Gitleaks; the loop executes `missing` and `wrong` for each. |
| Correct version parsing | ⚠️ | The gate parses the stipulated native forms correctly (`version: 0.11.0`, `v3.14.0`, `8.30.1`). However, the contract never invokes `--ci` with all three correct fake responses, so it does not prove that a valid set is accepted. See Important finding I1. |
| CI preflight precedes core syntax and root tests | ✅ | The new `--ci` block is lexically before `quality_run_core`; every six-case assertion requires both markers to remain empty. |
| Offline has zero optional-tool probes | ✅ | The only `command -v` and version calls for ShellCheck/shfmt/Gitleaks are under `[[ "$mode" == --ci ]]`; report records the pre-existing poison-boundary regression as passing. |
| rc, diagnostics, and PASS suppression | ✅ | Missing/wrong paths call `quality_protocol_error` (rc 2); each case asserts tool plus expected version in stderr, empty markers, and absent global PASS. |
| Budget, per task | ✅ | Package is `scripts/check.sh` +11/-0 (≤15) and `tests/test-quality-gate.sh` +5/-0 (≤20). Report’s stated cumulative totals, gate +11/-0 and test +5/-0 versus the task caps 70/110, are consistent with this package. |

## ② Quality

| Check | Verdict | Assessment |
|---|---|---|
| YAGNI | ✅ | The diff only adds the requested CI-mode preflight and its focused contract cases. |
| Tests genuinely validate behavior | ❌ | Failed-version coverage is real, but positive acceptance of the complete valid tool set is absent; a false rejection of valid Gitleaks can evade all six cases. |
| No literal duplicated logic blocks | ✅ | The tool cases and fake installation are table/loop driven; no material copied per-tool blocks were introduced. |
| Error paths handled | ✅ | Command absence and version mismatch both produce the protocol-error path before core execution; tests check its externally visible contract. |

## Findings

### Important

- **I1 — Valid Gitleaks can be rejected without failing this contract.**
  At [tests/test-quality-gate.sh:22](/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/tests/test-quality-gate.sh:22), the suite only runs `--ci` after making one tool missing or wrong. For the Gitleaks target, an implementation that rejects the correct `8.30.1` response also returns rc 2 with `gitleaks` and `8.30.1` in stderr, so both existing Gitleaks cases pass. This does not establish the required acceptance direction of fixed-version parsing.

  Suggested diff: after the six-case loop, run `--ci` once with all `install_ci_tools` responses intact and the existing invalid `bad.sh`; assert preflight reaches the syntax marker, rc is `1` from syntax (not `2`), root-test marker remains empty, and no global PASS appears. This stays within the task’s test budget.

### Blocking

None.

### Minor

None.

## ⚠️ items

- The positive acceptance test described in I1 is not present. This is an important test-quality/spec-evidence gap, not an implementation failure established solely from the supplied diff.

Counts: blocking 0, important 1, minor 0, ⚠️ 1.
