# 03a2 requirements v5.6 review — round 2

Reviewer: `review_plan_v5_2`

Verdict: **PASS** — blocker 0 / important 0 / minor 0

## Round 1 findings closure

- **I1 closed** — `requirements.md:29,33,48` now makes the ownership boundary exclusive and observable: one entrypoint invocation calls the driver exactly once for `protocol` and exactly once for `run-matrix`, never calls `self-test`, records the fake-driver argv sequence as exactly `protocol,run-matrix`, and leaves the accepted driver's `self-test` to a separate controller command. This matches PLAN `:107,111` and the round7 driver/entrypoint split; it cannot falsely pass after executing an internal 37-case self-test plus the external 37-row matrix.
- **I2 closed** — `requirements.md:33,55` pins the exact version evidence (`shfmt` `v3.14.0`, ShellCheck version field `0.11.0`), the only checked file (`tests/test-session-path-races.sh`), and the effective argv for `shfmt -d -i 2 -ci -bn`, `shellcheck -x --severity=warning`, and `bash -n`, with zero differences/diagnostics required. `--severity=warning` is the long-form equivalent of round7's proven `-S warning`.
- **I3 closed** — `requirements.md:31,53` adds an isolated 03a2-own rollback: delete only the entrypoint in a candidate checkout, then require the private driver's 38-byte self-test PASS, offline PASS, zero discovered race entrypoints, and no 03b files. This agrees with PLAN `:197,219` and does not make rollback depend on a future consumer.
- **M1 closed** — `requirements.md:33,55` defines the SHA object and comparison precisely: in each checkout, hash the current tracked provider and driver immediately before the tests and compare both after all tests. Accepted dependency identity remains tied to zero dependency diff plus ledger evidence, so a real depth-1 checkout never needs a historical object.

## Scope and consistency check

- R1–R10 remain cohesive and mechanically observable. The priority is unchanged and closed: generate/validate the owned matrix first; provider absence is inert but an existing provider's anchor damage fails closed; driver absence is inert but unsafe type/protocol/execution damage fails closed; only then may the explicit flag, missing foundation, or unavailable core select the common zero-case inert oracle; dependency-present default/all must execute and log all 37 rows.
- The entrypoint owns only the four-column matrix, dependency dispatcher, driver invocation, ordered case-log reconciliation, and final 41-byte summary. It neither copies the driver's family/oracle/self-disproof implementation nor publishes a runtime API or capability marker (`requirements.md:19-35,67-69`).
- Full-history and real file-URL depth-1 evidence, offline default discovery, exact-one-file/400-line bounds, six-column continuous all-PASS manifest, accepted-HEAD ledger write, and the hard 03b ordering gate are mutually consistent (`requirements.md:33-37,54-63`). An inert PASS still cannot unlock 03b.
- No new conflict was introduced between independent driver self-test acceptance and the entrypoint's exact two driver invocations, between rollback and default discovery, or between per-checkout integrity hashes and shallow-clone operation.

## Mechanical checks

- `check-req.py`: rc0
- `check-criteria.py`: rc0
- `check-analyze.py`: rc0
- `check-plan.py`: rc0
- `git diff --check`: rc0
