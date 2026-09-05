# Task 2 diff review r1 — canonical verifier provider

## Verdict

**PASS — B=0 / I=0 / M=0**

Review scope is only task 2, commit `75221708be3f365663d7d8c00e73c57a761f41c2` against task-1 base `354d8101648060107b3e0bc87708a10a724db201`.  This is a read-only diff/static review.  The reported shfmt, ShellCheck, `bash -n`, and base-contract execution were not rerun.

## Change and evidence boundary

- Diff package shows exactly one added executable file, `common/.harness/bin/verify-sidebar.sh`, at `202` added / `0` removed lines; read-only Git metadata confirms mode `100755`, no other source path changed, a clean worktree, and no diff-check output.
- The installed file is byte-identical to the approved provider prototype (`cmp` result `0` observed during this review).  The task report independently records the same SHA-256, `202` lines, mode, fixed-tool results, red absence evidence, and exact base-test output.
- `docs/verifier-contract.md` and `tests/test-verifier-contract.sh` belong respectively to the other exact-3 owners/tasks; their absence from this task-2 commit is correct and is not scope leakage.  The R3/R4 exhaustive matrix is explicitly reserved for 05a, not a missing task-2 requirement.

## Requirement-to-evidence review

| Requirement | Verdict | Static/diff evidence |
|---|---|---|
| R1 — independent canonical CLI, accepted set/preflight order, serial and uniform ADB argv | ✅ | New canonical path only. `parse()` (lines 22–68) rejects help combinations, duplicate flags, invalid/missing `--since`, unknown/positional inputs before real `--allow-skip`, serial, then runner preflight; all preflight exits are `2`.  Standalone help exits before serial/query.  Real command construction is consistently `['adb', '-s', serial] + args` (line 94); runner preserves this argv after `--` (lines 95–96). |
| R2 — five logical assertions and direct/runner transport contract | ✅ | Exactly one `mark()` path exists for boot (105–114), system_server (116–125), crash (127–167), service (169–178), and package (180–189); output emits those five detail rows before summary (191–194).  Query failure takes precedence for every item.  Runner preflight uses absolute path, `lstat`, regular/non-symlink, EUID ownership and executable access (57–67); runner gets lowercase documented keys plus `--`, captures stdout, inherits stderr, and normalizes signal statuses (90–102).  Direct mode suppresses child stderr. |
| R3 — baseline/window and byte-level crash parsing | ✅ | Default path parses only full `btime[ \\t]+[0-9]+[ \\t]*` records, fails zero/multiple/malformed candidates, and only invokes logcat when a baseline is valid (127–148).  Explicit epoch parsing/padding is handled by `EPOCH`/`epoch()` and the `-T SEC.NNNNNNNNN` argv (10, 71–75, 146–148).  `lines()` is LF-only with at most one trailing CR removed (78–79); crash classification checks the original first byte against ASCII `0`–`9` before token parsing (150–167), preserving the required header behavior. |
| R4 — five grammars and category semantics | ✅ | Boot scalar, PID-list, crash, service bytes regex, and package bytes regex are all evaluated with query failure first, parse failure distinct from business absence, and package as the sole SKIP producer (105–189).  Service/package ignore only empty LF records; service target matching is the captured exact name `sidebar`, package matching is the exact complete package line. |
| R5 — summary, terminals, and exit statuses | ✅ | Counts are computed exclusively from the five recorded results and printed as the required summary (191–194).  FAIL returns `RESULT FAIL`/1; strict SKIP returns `RESULT INCOMPLETE`/2; only demo-enabled `allow_skip` can produce `RESULT PASS (SKIP allowed)`/0 (195–201). |
| R6 — demo transport and fixtures | ✅ | `query()` selects fixtures before any command construction when demo is true (90–93), so no real ADB or runner invocation is possible.  All twelve named fixture families map directly to data values/failure statuses, defaults yield the five passing defaults, and no fixture is evaluated as shell code. |

No R→E row has an associated finding.

## Quality review

### Scope and ownership

✅ No old verifier, session/resource-lease, test, document, adapter, or future-stage file is changed.  The one-file/202-line commit is within the task’s mechanical-copy instruction and preserves the intended physical provider boundary.

### Assertion effectiveness

✅ The already-present base test has meaningful, non-tautological integration assertions for this provider: exact five-detail PASS output and demo zero-runner-log check (test lines 57–62); complete default runner argv/order/serial comparison (64–73); explicit-baseline padding plus a runner nonzero/stderr/detail/terminal path (75–85); and representative CLI, serial, runner-preflight, and standalone-help zero-query checks (87–97).  This review does not count its successful execution anew; the task report supplies that evidence.

✅ It deliberately does not duplicate the exhaustive grammar, all query-failure, and mutation matrix, which the specification assigns to 05a.  That is a bounded coverage division, not a weakened task-2 oracle.

### Duplication and maintainability

✅ The Python implementation is a single physical provider behind a two-line Bash launcher.  The apparent prototype copy is intentional approval material outside the implementation diff; no second active provider or repeated legacy implementation was introduced.  Shared `query()`, `lines()`, and `mark()` helpers prevent divergent adapter/parser behavior.

### Error paths

✅ CLI/serial/real-runner preflight paths fail closed with rc 2 before query transport; direct child stderr is suppressed, runner stderr is deliberately inherited; an `OSError` at launch produces the specified stable runner-execution diagnostic, rc 126, and the corresponding item’s query-failed classification.  Bad/default baseline does not fall through to logcat, while later service/package assertions still settle so the result cardinality remains five.

## Findings

### Blocking

None.

### Important

None.

### Minor

None.

## Review disposition

Task 2 is acceptable as the narrowly scoped, approved-prototype installation.  Subsequent owner tasks remain responsible for the contract document, the full exact-3 acceptance, and the explicitly deferred 05a exhaustive assurance; this review neither approves nor starts those later stages.
