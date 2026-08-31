# Task 1.8 review — round 1

## Verdict

**PASS** — the reviewed diff `d92af9d1..61e5fa8f` meets Task 1.8's stated requirements. This was a static diff/source review only; the task report's commands were not re-run.

## 1. Specification compliance

| Requirement | Result | Evidence |
|---|---|---|
| Register `legacy`; run the three preserved legacy entrypoints independently and treat every non-zero result as a failure | Pass | `device_safety_run_legacy` creates the `legacy` fixture, lists exactly Claude, Codex, and common paths, and wraps each `bash "$legacy_test"` with `|| device_safety_fail` (lines 710–725). |
| Private fake `adb` is first in `PATH` for each legacy process | Pass | The private bin from `device_safety_fake_adb_install legacy demo-serial` is saved in `fake_bin`; every legacy invocation receives `PATH="$fake_bin:$PATH"` (lines 713–723). The installed fixture contains an executable fake `adb` and no other fixture command (lines 35–64). |
| Default `all` order and failure short-circuit | Pass | The registered `all` runner calls `fixture`, `claude-invalid-serial`, `claude-valid-serial`, `flag-demo`, `skills`, `legacy` in the required order, returns immediately on a scope error or recorded failure (lines 727–734). |
| No-argument default and unknown-scope compatibility | Pass | Empty `DEVICE_SAFETY_TEST_SCOPE` selects `all` (line 747); registered named scopes remain available; unknown values retain the existing stderr diagnostic and exit 2 (lines 19–29, 753–765). Positional arguments still fail with exit 2 (lines 739–742). |
| Failure cannot emit the total success line | Pass | `main` returns on scope failure and returns 1 when `DEVICE_SAFETY_FAILURES` is non-zero before the final `printf` (lines 748–750). |
| Successful full run has the exact final line | Pass | Only `all` prints `RESULT PASS  device safety\\n`, after all checks have succeeded (line 750). |
| Executable bit and legacy paths retained | Pass | At reviewed commit, `tests/test-device-safety.sh` and all three legacy entry scripts are mode `100755`; all three referenced paths exist in the commit tree. |

## 2. Quality

The change is minimal, follows the task-prescribed control flow verbatim, uses local variables for added state, and does not introduce unrelated behavior. It preserves the existing failure-counter convention, so a failed legacy entry is surfaced even though the loop continues to report any later legacy failure; the enclosing `all` runner then stops before subsequent scopes (there are none after `legacy`).

## Findings

- Blocking: 0
- Important: 0
- Minor: 0

## ⚠️ Notes

- 0

## Result

**PASS**
