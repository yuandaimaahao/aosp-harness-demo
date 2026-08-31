# Task 1.6 Review — Round 1

Review target: `b726dbf8..8a9e1963` (`tests/test-device-safety.sh` only).  This is a static diff review; the supplied validation commands were not re-run.

## Result

**NEEDS_CHANGES**

Findings: **1 blocking, 1 important, 1 minor**.

## ① Specification compliance

| Requirement / task step | Assessment | Evidence |
|---|---|---|
| R3 / step 1: exact `device_serial` assignment and complete regex precede first ADB | Partial | The required literals are used and empty matches fail at `tests/test-device-safety.sh:354-363` (reviewed commit). However `-m1` deliberately accepts duplicate matching lines, so the oracle proves only that *one* occurrence is early, not an unambiguous preflight. |
| R3 / step 2: every `root`/`remount`/`push`/`reboot`/`shell` invocation has the fixed target; no bare ADB or other target variable | Fail | The oracle checks a matched **line**, not every invocation on that line, and it ignores all ADB invocations outside the five-word filter (`:365-376`). See blocking and important findings. |
| R6: static contract oracle does not execute skill code | Pass | It extracts fenced text and uses `grep`, `cut`, and shell string comparison only; it does not `source`, `eval`, or execute the extracted block (`:344-376`). |
| Task step 3: `skill-contract` scope invokes both skills | Pass | Registered at `:409`; it calls `device_safety_check_skill_file` for both prescribed skill paths (`:379-384`). |

## ② Quality

The function is compact, has clear failure messages, handles a missing/empty extracted block fail-closed, and uses an exact expected prefix. Its parsing model is nevertheless too shallow for a security oracle: it treats a complete source line as one ADB command.

## Findings

### Blocking

1. `tests/test-device-safety.sh:365-373` — A bare or differently targeted second ADB command on a line that starts with a compliant command passes the oracle.

   For example, this is selected once, its trimmed text has the expected prefix, and therefore passes even though reboot is bare:

   ```bash
   adb -s "$device_serial" root; adb reboot
   ```

   The same bypass works with `&&`, `||`, or a pipe, including `adb -s "$device_serial" shell true && adb -s "$other_serial" reboot`. This contradicts the required per-command coverage and directly weakens R3/R6. Parse/split every command invocation (or reject command-chain lines) and validate each `adb` token, rather than accepting the whole line based on its first prefix.

### Important

1. `tests/test-device-safety.sh:373` — The candidate filter ignores bare ADB and alternative target variables unless the same line also contains one of `root|remount|push|reboot|shell`.

   Consequently `adb devices`, `adb -s "$other_serial" wait-for-device`, or `adb -s "$other_serial" install x.apk` is never read by the loop and does not affect `adb_count`. The task explicitly requires that a target block containing a bare ADB or another target variable report `bare adb`; scan all ADB invocations in the block and separately enforce the allowed command set/prefix.

### Minor

1. ⚠️ `tests/test-device-safety.sh:357-358` — `grep -m1` silently collapses duplicate exact `device_serial` or regex matches. Empty matches are handled correctly, but duplicates are neither rejected nor surfaced; the check only proves the first occurrence precedes the first detected ADB. If the contract intends a single, auditable preflight, count exact occurrences and require one each. This is not independently exploitable when the first complete preflight is valid, but it makes the oracle less diagnostic and less strict than the “unique target block / exact preflight” intent.

## Non-findings

- The exact serial assignment and regex literals match the task brief.
- Missing `first_adb`, serial, or regex values are fail-closed before numeric comparison.
- The oracle does not execute extracted Markdown/Bash code.
