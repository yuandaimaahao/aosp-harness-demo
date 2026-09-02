# 03a2 session path race matrix — sizing prototype report

Status: **PASS**

This is throwaway design evidence only. It does not modify the tracked production entrypoint, provider, foundation, private driver, any specification, `STATE.md`, or ledger.

## Question and result

Question: can one default-discovered shell entrypoint own the 37-row matrix, dependency priority, inert surface, private-driver invocation, ordered case-log reconciliation, and rollback contract while remaining an exact-one-file change under 400 physical/numstat lines?

Result: yes. The executable prototype is **137 physical lines** and a temporary candidate commit is **exact1 / 137 added+deleted lines**, leaving 263 lines of hard-gate margin. The accepted 400-line Python driver is consumed unchanged.

Artifacts:

- `prototype/tests/test-session-path-races.sh` — throwaway entrypoint sized as the future owned file.
- `prototype/fixtures/*.py` — controller-only damaged/fake driver fixtures; not proposed production files.
- `run-sizing.sh` — throwaway evidence controller; stages fixtures and candidate checkouts outside the repository.
- `evidence.log` — preserved output of the successful complete run.

## Contract demonstrated

- Default and explicit `all` both return rc0, stderr 0B, and the exact 41-byte entrypoint summary. The real accepted driver executes the generated exact 37-row matrix and the entrypoint accepts only an ordered 37/37 unique CASE_LOG with the nine continuous family counts `9/3/9/3/3/3/3/3/1`.
- A fake driver records exactly two calls in order: one `protocol` and one six-argument `run-matrix FOUNDATION PROVIDER ABSENT_WORKSPACE CASE_TSV CASE_LOG`. It records zero `self-test` calls. The controller independently verifies accepted-driver protocol (28B) and self-test (38B) in both checkout shapes.
- Matrix duplicate damage fails rc1/stdout0 before an absent provider can select inert and before the fake driver is touched.
- Provider absence is inert before driver access. Each of the three anchors was tested missing and duplicated against each representative downstream state—foundation absent, core unavailable, and explicit dependency-absent—for **18 fail-closed combinations**.
- Driver absence is inert. Symlink, directory, protocol mismatch, protocol rc failure, protocol stderr, Python syntax damage, run-matrix rc/stderr/summary damage, and an ordered-log duplicate all fail closed with rc1 and no PASS.
- Foundation absence, core unavailability, and explicit dependency-absent each call only driver protocol, execute zero run-matrix/self-test cases, pass the isolated core/four-public-API/marker absence oracle, and emit the same 41-byte summary.
- Unknown argument, extra `all` argument, and a value following `--dependency-absent` all fail rc1 with stdout 0B and no PASS.

## Fixed tools and checkout evidence

The host PATH initially lacked both formatters. The controller therefore downloaded the official fixed release binaries into a temporary directory, verified their own version outputs, and ran the exact required checks only on the entrypoint:

- `shfmt --version` → `v3.14.0`; `shfmt -d -i 2 -ci -bn ENTRY` → rc0, 0B diff.
- ShellCheck version field → `0.11.0`; `shellcheck -x --severity=warning ENTRY` → rc0, 0B diagnostics.
- `bash -n ENTRY` → rc0.

The runtime prototype itself performs no network access and does not depend on those tools; they are controller-only acceptance dependencies.

The controller built a temporary candidate commit containing only `tests/test-session-path-races.sh`, then cloned it twice:

| Checkout | History proof | protocol / self-test / direct | offline | dependency integrity |
|---|---|---|---|---|
| full | normal complete-history clone | 28B / 38B / 41B, stderr 0 | entrypoint discovered exactly once; gate PASS | current tracked provider+driver SHA-256 unchanged; clean |
| depth-1 | `--depth 1 file://...`; commit count 1; `.git/shallow` 41B | 28B / 38B / 41B, stderr 0 | entrypoint discovered exactly once; gate PASS | current tracked provider+driver SHA-256 unchanged; clean |

No depth-1 command queried a fixed historical commit or SHA.

## Independent rollback

In a third isolated candidate checkout, the controller committed deletion of only `tests/test-session-path-races.sh`. The private driver self-test still emitted its exact 38-byte PASS, offline still passed, the root gate discovered the race entrypoint zero times, no 03b provider/test existed, and the checkout remained clean. This demonstrates that 03a2 can roll back independently without changing 03a/03a1 or depending on 03b.

## Design implications and residual risks

1. The 137-line result has ample hard-gate margin; design should lock a single owned production file rather than split the entrypoint.
2. Exact byte capture for both driver commands costs more lines than round7's command-substitution prototype but closes the missing-LF/extra-LF and nonempty-stderr gaps. Those checks should not be compressed away during implementation.
3. `HARNESS_TEST_MATRIX_DAMAGE` is a throwaway test-only injection used by the prototype's recursive self-disproof, not a runtime API or capability. The design should explicitly classify the final mutation mechanism as test-only and avoid treating it as a consumer contract.
4. The fixed tool binaries were bootstrapped from official release URLs because the host PATH had none; their exact versions and behavior were verified, but this prototype did not add a new checksum/provisioning contract. Implementation acceptance should reuse the project's pinned controller/CI provisioning.
5. Fixture drivers and the controller are evidence assets only. The proposed BASE..HEAD source file list remains exactly `tests/test-session-path-races.sh`.

## Reproduction

With `shfmt v3.14.0` and ShellCheck `0.11.0` on PATH:

```bash
bash .spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03a2-session-path-race-matrix/run-sizing.sh
```

Or point the controller at a directory containing those exact binaries:

```bash
HARNESS_SIZING_TOOLS=/path/to/pinned-tools bash .spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03a2-session-path-race-matrix/run-sizing.sh
```
