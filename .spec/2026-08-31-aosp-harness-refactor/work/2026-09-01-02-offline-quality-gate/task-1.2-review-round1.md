# Task 1.2 independent diff review — round 1

## Verdict

**NEEDS_CHANGES** — 0 blocking, 2 important, 0 minor findings; 0 items are `⚠️ unable to determine from the supplied diff`.

This review is limited to the task brief, implementer report, supplied review package, and review contract.  Reported green-stage commands were not re-run.

## ① Specification conformity

| Requirement / behavior | Result | Evidence and conclusion |
|---|---|---|
| Managed set: `.sh` extension or exact Bash shebang; spaces and LF names | ✅ | `check.sh` uses `find -print0`, reads the first line without word splitting, and emits NUL paths.  The contract fixture creates and counts `entry`, `space entry`, `line\nentry`, and `bad.sh`. |
| Managed set: no symlink, `.git`, or `.spec` | ✅ | `find` is limited to `-type f`, does not follow links by default, and prunes both directories.  The fixture creates the excluded files and an external symlink, then rejects their syntax-log entries. |
| Absolute repository root | ✅ | The gate derives `repo_root` from `${BASH_SOURCE[0]}` with `pwd -P` before discovery and `cd`s there. |
| NUL boundary and `LC_ALL=C` | ✅ | Both discovery pipelines use `-print0` / `read -d ''` / `sort -z`; the fixture fake `sort` requires `LC_ALL=C` and validates an LF path. |
| Syntax precedes all root tests | ❌ | The implementation has separate syntax and test loops in the correct order, but the contract does not prove the required *all syntax records before the first root marker* temporal relation.  It only proves that a failing syntax prevents root tests. See I1. |
| C-order, stdout/stderr forwarding, and fail-fast | ✅ | Root tests are NUL-sorted, run directly (therefore preserve both streams), and return after the first non-zero.  The fixture checks `amz`, exactly one `OUT`/`ERR`, and no `z` after `m` fails. |
| Nested quality-gate invocation | ✅ | Every discovered root test receives `QUALITY_GATE_NESTED=1`; the fixture test asserts child output and a zero body marker. |
| Poison boundary and `CURRENT_FEATURE` hashes | ✅ | The real-repository case uses `GIT_ALLOW_PROTOCOL=file`, private poison commands, Python `timeout=30`, one child-marker count, poison-log emptiness, and before/after `git hash-object` comparison. |
| rc and final success line | ✅ | Preflight paths retain rc 2 assertions; the core returns/normalizes failure to 1 before the PASS print; the success case checks rc 0 and exact final line. |

## ② Quality

| Check | Result | Notes |
|---|---|---|
| YAGNI | ✅ | Diff is confined to the two task-owned files and implements only offline discovery/core execution plus its contract coverage. |
| Verification authenticity | ❌ | Two brief-mandated behavioral assertions are absent: the syntax-to-root temporal order and invocation from an unrelated current directory. See I1 and I2. Other assertions are concrete rc, marker, stream, and byte-level checks rather than vacuous command execution. |
| Literal duplication | ✅ | No material copied logic block is introduced; the repeated fixture setup is small and serves distinct cases. |
| Error paths | ✅ | CLI and all ten missing-command cases check rc 2, stderr diagnostic, zero markers, and no PASS; syntax and test failure paths normalize to rc 1 and short-circuit. |

## Findings

### Important

#### I1 — Contract does not assert that all syntax checks finish before any root-test execution

`tests/test-quality-gate.sh`, added block beginning at review-package line `+run_core()`: `syntax_marker` and `root_log` are separate files. The failing-syntax case proves root tests do not run after a syntax *failure*, but the successful case only later validates the completed syntax log and `amz`; it cannot distinguish the required sequence from an implementation that runs some root test after an earlier successful syntax check and before later syntax checks.

Suggested diff-line change: in the fake `bash` (`prepare_path`, review-package added line beginning `[[ "$1" == -n ]]`) and each fixture root test, append tagged NUL records to one shared event log. After successful `run_core`, assert all expected `syntax:<path>` records occur before the first `root:` record, in addition to the existing exact managed-set assertions.

#### I2 — Contract omits the brief's unrelated-working-directory absolute-root regression

The brief explicitly requires invoking the fixture gate from an unrelated directory and proving it does not execute that directory's `tests/test-poison.sh`. The supplied added test block never changes directory before `run_core`; it therefore validates the code's root derivation only indirectly, not its externally observable behavior.

Suggested diff-line change: after the successful fixture-core case (before mutating `test-m.sh` is suitable), create a separate temporary directory containing `tests/test-poison.sh` that writes an `outside_marker`; invoke `("$host_bash" "$fixture/scripts/check.sh" --offline)` from that directory, then assert the fixture's expected child/root behavior and `[[ ! -s "$outside_marker" ]]`.

### Blocking

None.

### Minor

None.
