# Task 1.6 Review — Round 3

Review target: `cab162d9..1c49ee42` (`tests/test-device-safety.sh` only). This is an independent static review of the supplied diff; validation commands in the fix report were not re-run.

## Result

**NEEDS_CHANGES**

Findings: **1 blocking, 1 important, 0 minor**.

## ① Specification compliance

| Review item | Assessment | Evidence |
|---|---|---|
| Operators immediately adjacent to `adb` | Partial | The new token boundary correctly finds `adb;`, `adb&&`, `adb|`, and parenthesized forms, and the new self-tests cover `root; adb;` and `adb&&`. It does not include redirection operators. In `adb -s "$device_serial" root; adb>/tmp/adb.out`, the first token is counted, the line has the expected prefix, and the second bare invocation is not found because the character after it is `>`. The same applies to `<`, `>>`, `>&`, `<<`, and `<<<`. |
| Same-line / commented preflight | Pass | Leading-whitespace comments are skipped before counts are updated; a same-line duplicate assignment is not an exact assignment and is rejected by the assignment check. The added synthetic `same-line` and `comment` cases exercise both paths. |
| Target-variable reassignment | Fail | Only `device_serial[[:space:]]*=` is rejected. Bash scalar concatenation, e.g. `device_serial+=-other`, does not match that expression, mutates the validated value, and is followed by an apparently compliant `adb -s "$device_serial" root`. The literal-prefix check then passes although the command targets a different serial. |
| All ADB invocations | Fail | Because redirection-adjacent invocations above are not tokenized, the oracle does not prove every invocation is fixed to `device_serial`. This violates the R3/R6 per-command proof, even though normal subcommands and the prior semicolon / logical-operator cases are now covered. |
| No execution of skill code | Pass | The changed code only extracts fenced text and examines it using shell string operations and `grep`; it does not `source`, `eval`, or invoke the extracted Markdown body. |
| Scope | Pass | The supplied diff changes only `tests/test-device-safety.sh`, directly within Task 1.6's static safety oracle. No out-of-scope production or documentation changes are present. |

## ② Quality

The change is materially better than Round 2: it counts matched commands on each line, ignores full-line comments, rejects ordinary reassignment, and carries the formerly missing cases in self-tests. However, it is still an incomplete line-level approximation of Bash command words. The omission of redirection boundaries and compound assignment means the oracle can report a safe contract for unsafe executable snippets. Add synthetic cases for at least `adb -s "$device_serial" root; adb>/tmp/adb.out` and `device_serial+=-other`, then make the matcher/reassignment guard reject them (prefer a deliberately conservative rule over partial shell parsing).

## Findings

### Blocking

1. `tests/test-device-safety.sh:382-388` — The ADB token matcher omits redirection delimiters. A compliant first command plus `adb>/tmp/adb.out` on the same line is accepted as one compliant ADB token, leaving the trailing bare ADB invocation unexamined. This fails R3/R6's requirement that every ADB command be explicitly targeted. Recognize redirection starts after `adb` (including `>`, `<`, and their compound forms), or conservatively reject any unparsed `adb` command word; add the exact mutation to `skill-contract-selftest`.

### Important

1. `tests/test-device-safety.sh:370-375` — The reassignment guard does not catch Bash `+=` assignments. `device_serial+=-other` changes the target after validation without matching `device_serial[[:space:]]*=`, then `adb -s "$device_serial" root` satisfies the expected-prefix check. Reject all assignment operators for `device_serial` after the required single initialization, and add this mutation to `skill-contract-selftest`.

### Minor

None.

## Final

**NEEDS_CHANGES** — specification compliance is not yet closed; quality needs changes. Counts: **1 blocking, 1 important, 0 minor**.
