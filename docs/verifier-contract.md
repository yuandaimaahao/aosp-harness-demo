# Verifier contract v1

Canonical entry: `common/.harness/bin/verify-sidebar.sh [--demo] [--since EPOCH] [--allow-skip]`.
`--help` is accepted only alone. The parser first rejects repeated flags, missing/extra/invalid
`--since` values, help combinations, unknown options and positional arguments; real mode rejects
`--allow-skip`; demo mode accepts it; then an absent or nonmatching `ANDROID_SERIAL`. The serial grammar is
`^[A-Za-z0-9][A-Za-z0-9._:-]*$`. All preflight failures are rc 2 with zero queries.

## Query transport

Real mode issues these separated argv in order (the btime query is omitted with `--since`):

1. `adb -s SERIAL shell getprop sys.boot_completed`
2. `adb -s SERIAL shell pidof system_server`
3. `adb -s SERIAL shell cat /proc/stat`
4. `adb -s SERIAL logcat -b crash -d -v epoch,nsec -T SEC.NNNNNNNNN`
5. `adb -s SERIAL shell service list`
6. `adb -s SERIAL shell pm list packages`

By default, query stderr is suppressed. The private composition seam
`HARNESS_VERIFIER_QUERY_RUNNER=/absolute/path` requires an EUID-owned, executable, regular,
non-symlink file. It receives `QUERY_KEY --` followed by the exact argv above, writes query bytes
to stdout, diagnostics to inherited stderr, and returns the query status. Keys are
`boot`, `system_server`, `boot_time`, `crash`, `service`, `package`. This is a transport seam, not
an authenticity boundary: its caller already controls `PATH`; 09 binds it only to its trusted 06
adapter. An unset seam preserves direct operation; an invalid seam fails preflight before queries.
A runner signal becomes status `128+signal`. If exec fails after preflight, the provider writes
`query runner execution failed` to stderr and classifies that assertion as query-failed.

## Five assertions

Input is bytes split only at LF; one trailing CR per line is removed. Scalar boot/system outputs
trim only byte space, tab, and LF at the two ends; token separators are only space/tab. List empty
LF records are ignored where their rows state “nonempty”; crash applies its explicit header rules.

| Item | Legal grammar | Empty | Legal target absent | Malformed | Satisfied |
|---|---|---|---|---|---|
| boot | ASCII-trimmed `0` or `1` | parse FAIL | `0`: business FAIL | other: parse FAIL | `1`: PASS |
| system_server | ASCII-trimmed `[1-9][0-9]*` tokens separated by space/tab | business FAIL | N/A | zero, leading zero, other: parse FAIL | legal list: PASS |
| crash | rules below | empty buffer: PASS | timestamp `>=` baseline: business FAIL | btime/numeric token: parse FAIL | only headers/earlier records: PASS |
| service | `^[0-9]+[ \t]+[^ \t]+:[ \t]+\[[^][\r\n]+\][ \t]*$` | business FAIL | no exact `sidebar:` name: business FAIL | any nonempty bad line: parse FAIL | exact name: PASS |
| package | `^package:[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$` | SKIP | no exact target line: SKIP | any nonempty bad line: parse FAIL | exact target: PASS |

A nonzero query status is that assertion's `query failed` FAIL. Without `--since`, crash requires
exactly one `btime[ \t]+[0-9]+[ \t]*` line; zero, duplicate or malformed btime means parse FAIL and
zero logcat calls. `--since` accepts nonnegative seconds plus optional 1–9 digit fraction and pads
to nine digits. In crash output an empty line or a line whose original first byte is not ASCII
`0`–`9` is a header; otherwise the first space/tab-delimited token must be a legal epoch.

## Output and demo

Details are always ordered boot, system_server, crash, service, package and start with exactly
`PASS  `, `FAIL  ` or `SKIP  `. They are followed by `SUMMARY PASS=n FAIL=n SKIP=n`, whose sum is 5.

| State | Terminal | rc |
|---|---|---|
| any FAIL | `RESULT FAIL` | 1 |
| no FAIL and at least one SKIP | `RESULT INCOMPLETE` | 2 |
| five PASS | `RESULT PASS` | 0 |
| demo SKIP plus `--allow-skip` | `RESULT PASS (SKIP allowed)` | 0 |

Only exact strict PASS is delivery evidence. Demo performs zero external queries. Query failure
fixtures are `DEMO_BOOT_QUERY_FAIL`, `DEMO_SYSTEM_SERVER_QUERY_FAIL`,
`DEMO_BOOT_TIME_QUERY_FAIL`, `DEMO_CRASH_QUERY_FAIL`, `DEMO_SERVICE_QUERY_FAIL`, and
`DEMO_PACKAGE_QUERY_FAIL`. Value fixtures are `DEMO_BOOT_COMPLETED`, `DEMO_SYSTEM_SERVER`,
`DEMO_BOOT_TIME`, `DEMO_CRASH_LOG`, `DEMO_SERVICE_LIST`, and `DEMO_PACKAGE_LIST`. Defaults yield
five PASS values; fixtures are data, never shell code.
