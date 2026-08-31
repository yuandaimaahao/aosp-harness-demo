# Task 1.6 Review — Round 2

Review target: `8a9e1963..cab162d9` (`tests/test-device-safety.sh` only). This is an independent static diff review. The supplied validation commands were not re-run.

## Result

**NEEDS_CHANGES**

Findings: **1 blocking, 1 important, 0 minor**.

## ① Specification compliance

| Review item | Assessment | Evidence |
|---|---|---|
| Chained second `adb` | Fail | The revised token matcher only accepts `adb` followed by end-of-line or whitespace. A valid second shell command written with an operator immediately after its name is missed. For example, `adb -s "$device_serial" root; adb;` has one matched token (the first command), its line begins with the expected prefix, and therefore passes. The trailing bare `adb` is executed but is not counted. This leaves the Round-1 per-command bypass open. |
| All ADB subcommands | Fail | The loop now scans all matched `adb` lines rather than only the former five-word filter, which correctly covers normal `adb devices` and `adb -s "$other_serial" wait-for-device` forms. However the matcher above still omits zero-argument/operator-terminated invocations such as `adb;`, `adb&& ...`, and `adb| ...`; therefore it does not establish coverage of every ADB invocation. |
| Other target | Partial | A normally written alternate target, e.g. `adb -s "$other_serial" wait-for-device`, is now rejected, including on a separate line; the added self-test proves that case. But a post-validation reassignment such as `device_serial="$other_serial"` before `adb -s "$device_serial" root` passes: the command retains the literal expected prefix while targeting a value no longer derived from `ANDROID_SERIAL`. The oracle must prevent/reject reassignment (or otherwise prove the command argument remains the validated value). |
| Unique preflight is closed | Fail | `grep -Foc` counts matching *lines*, not occurrences. Two exact assignments or regex preflights on one physical line count as one, so the new duplicate guard is bypassable. More critically, both preflight literals can appear in comments before the command and satisfy the line-number/count checks without executing any validation. The oracle needs to distinguish executable Bash from comments and require exactly one actual assignment and guard before the first ADB invocation. |
| No execution of skill code | Pass | The changed contract path only extracts fenced text and uses `grep`/`cut`/shell string operations; it does not source, eval, or run extracted Markdown content. |
| No scope creep | Pass | The target diff modifies only `tests/test-device-safety.sh`; the new scope and synthetic static fixtures are directly related to the Round-1 findings. |

## ② Quality

The patch improves diagnostics and fail-closed returns, expands scanning beyond the five specified subcommands, and adds useful synthetic cases for the original bypasses. The parser remains a line-oriented lexical heuristic where shell syntax matters: its incomplete token boundary and absence of comment/reassignment handling leave the security oracle unsound. The self-tests do not cover these residual forms, so they cannot prevent regressions of the remaining gaps.

## Findings

### Blocking

1. `tests/test-device-safety.sh:365-378` — The `adb($|[[:space:]])` matcher misses an operator-terminated second command. A device block containing `adb -s "$device_serial" root; adb;` passes the current oracle even though it executes a second, bare ADB command. This violates R3/R6's per-command fixed-target proof and specifically leaves the chained-second-ADB requirement unclosed. Recognize shell command delimiters/operators after `adb` (or conservatively reject any line containing a second `adb` spelling) and add this exact mutation to `skill-contract-selftest`.

### Important

1. `tests/test-device-safety.sh:345-363, 365-378` — The preflight proof is syntactic but not closed: `grep -Foc` counts lines rather than duplicate occurrences, comment text is accepted as both preflight literals, and a later `device_serial` reassignment can redirect an apparently compliant `adb -s "$device_serial"` command. This does not prove that the unique, validated `ANDROID_SERIAL` value is the target. Count literal occurrences rather than lines, exclude comments, and reject assignments to `device_serial` other than the one required preflight; add same-line-duplicate, commented-preflight, and post-validation-reassignment synthetic cases.

### Minor

None.

## Final

**NEEDS_CHANGES** — specification compliance fails; quality needs changes. Counts: **1 blocking, 1 important, 0 minor**.
