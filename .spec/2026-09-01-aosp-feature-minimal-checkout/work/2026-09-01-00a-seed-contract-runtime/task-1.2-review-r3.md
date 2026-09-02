# Task 1.2 Fresh Diff Review R3

## Scope and verdict

- Base: `b9d61b7ae681b56a8b2c1caea833ebf165988d16`
- Head: `28e8f1b6c1c2690497185e103a44064a28378346`
- Reviewed immutable package: `review-b9d61b7a-28e8f1b6.md`
- Commits: `67cc360`, `5337b6d`, `28e8f1b`
- Overall: **FAIL**
- Standards: **PASS with 1 Minor judgement-call smell**; no documented repository-standard breach.
- Spec: **FAIL**; 3 Important findings, no Blocker.

## Standards

### Blocker

None.

### Important

None.

### Minor

1. Possible **Mysterious Name** readability smell (judgement call).
   - Evidence: `seed_contract_runtime.py:27-73` retains `_bad`, `_u`, `_i`, `_rel` and dense semicolon/list-comprehension control flow; `test_seed_contract_runtime.py:33-50` compresses the whole recursive matrix and many unrelated mutations into a few physical lines.
   - Impact: validation priority and stop-at-first behavior are difficult to audit; the carrier and matrix gaps below are obscured by the compression.
   - This is not a hard documented-standard violation. Exact-head parity, shared harness verification, and dev-sidebar verification all pass.

## Spec

### Blocker

None.

### Important

1. A malformed but valid-JSON `entry_kind` still escapes the required `ContractError` carrier.
   - Evidence: `seed_contract_runtime.py:42` dispatches with `dict.get(v["entry_kind"], _bad)` before proving that the enum value is hashable/string-valued.
   - Exact-head public-entry probes produced:
     ```text
     entry-kind-list TypeError None "unhashable type: 'list'"
     entry-kind-dict TypeError None "unhashable type: 'dict'"
     ```
   - This violates R3 closed-schema rejection and R12/Runtime API's unique expected-failure carrier. A later wrapper would misreport ordinary invalid descriptor data as `RUNTIME_INTERNAL`.
   - Required action: validate `entry_kind` as a string/member before dispatch and independently exercise list/object/scalar wrong types through `load_artifact`, asserting `DESCRIPTOR_SCHEMA_INVALID`.

2. The delivered evidence validator/domain dispatcher is not itself closed over the artifact envelope.
   - Evidence: `seed_contract_runtime.py:72-73` dispatches directly by kind but no longer validates exact integer `schema_version == 1`; `_request` at lines 48-50 only checks that the key exists.
   - Exact-head probes produced:
     ```text
     direct-validator-schema-2 OK 'aosp-harness/seed-request/v1\x00'
     direct-validator-schema-True OK 'aosp-harness/seed-request/v1\x00'
     ```
   - Public `load_artifact` now enforces the correct priority, but task 1.2's output is the closed `evidence-validation/v1` validator/domain capability consumed by later in-memory publisher paths. Calling its dispatcher accepts unsupported/bool schema versions.
   - Required action: keep the loader's early unsupported-schema priority while making the shared artifact validator enforce the same exact envelope for non-file callers; add direct-dispatch negative tests.

3. R1 Important #5 / R2 Important #3 remains open: the test is recursive, but it is not the required per-field boundary/order/domain-digest-change matrix.
   - Evidence: `test_seed_contract_runtime.py:44-48` recursively checks missing, one unknown key, and one placeholder type/null mutation. It does not give each numeric field its accept/reject safe bounds or assert that valid mutations of each load-bearing field change the corresponding digest.
   - At line 49, several categories are combined in one mutation. Stop-at-first means invalid `status_record_b64` masks `entry_kind`; invalid trace argv masks address-family/classification/path role/path base64; invalid journal argv masks cwd base64. Those later assertions are never established by that case.
   - The positive semantic arrays at lines 37-38 use repeated identical values, proving duplicate acceptance but not preservation of a distinguishable operand/argv order. No digest inequality/change assertion exists anywhere in `evidence-schema`.
   - This violates task step 1 and R4's explicit evidence requirement. It also failed to expose findings 1-2.
   - Required action: use independent table rows per field/category, distinguish semantic order with non-identical values plus a repeat, cover signed/unsigned accept/reject boundaries per applicable field, and assert key-reorder stability plus valid field-mutation digest change. Preserve the cumulative 75-addition ceiling by replacing/compressing existing cases; otherwise return to PLAN under R17.

## Prior-finding closure audit

| Prior finding | R3 status | Evidence |
|---|---|---|
| R1 B1 bool/int confusion | **Closed** | Exact `type(...) is int/bool` checks; public probes reject bool-as-int/int-as-bool. |
| R1 B2 project domain missing | **Closed** | Exact project domain and `_project` dispatch are present with an independent literal oracle. |
| R1 I3 malformed journal carrier | **Closed** | Record exact-shape validation precedes field access; scalar/list/null cases return `DESCRIPTOR_SCHEMA_INVALID`. |
| R1 I4 source root realpath | **Closed** | Normalized-realpath equality plus explicit NUL rejection; prior separator/symlink/NUL probes pass with `ContractError`. |
| R1 I5 per-field matrix | **Open** | Recursive coverage improved, but boundary/order/independent category/digest-change cells remain absent. |
| R1 M6 readability | **Open** | Dense names/control flow remain; Standards Minor above. |
| R2 I1 expected carrier | **Exact two reproductions closed; obligation still open** | Bogus `expected_kind` gives `ARGUMENT_ERROR`; NUL root gives `DESCRIPTOR_SCHEMA_INVALID`; unhashable `entry_kind` now reproduces raw `TypeError`. |
| R2 I2 unsupported-schema priority | **Closed at `load_artifact`** | Mixed schema=2 + kind mismatch/float both return `UNSUPPORTED_SCHEMA_VERSION`; shared direct validator gap is current finding 2. |
| R2 I3 per-field matrix | **Open** | Current finding 3. |
| R2 M4 readability | **Open** | Standards Minor above. |

## Verification evidence

- Exact-head isolated `git archive`; no real AOSP path read and no prohibited envsetup/lunch/build/sync/download command run.
- `PYTHONDONTWRITEBYTECODE=1 python3 common/tests/test_seed_contract_runtime.py canonical-core evidence-schema` -> exit 0; exact two PASS lines; stderr empty.
- `PYTHONDONTWRITEBYTECODE=1 python3 common/tests/test_seed_contract_runtime.py concurrent-core` -> exit 0; exact `PASS concurrent-core`; stderr empty.
- Exact-head old regressions: shared harness final line exact `RESULT PASS  shared Harness regression suite`; parity exact PASS; dev-sidebar demo final line exact `RESULT PASS`; all exit 0.
- `git diff --check b9d61b7a..28e8f1b6` -> exit 0, no output.
- File scope: PASS; only the two task-listed files changed.
- Budget: PASS at the hard boundary; `75` additions / `5` deletions (`53/2` runtime, `22/3` tests).
- Red evidence exists and records the intended `evidence validators missing` failure. The task report's green commands are reproducible, but the suite is not sufficient to establish the requested capability.

## Summary

- Standards findings: 1 Minor; worst is a judgement-call readability smell.
- Spec findings: 0 Blocker, 3 Important; worst is invalid descriptor data escaping the stable failure carrier.
- Prior closure: R1 has 4 substantive findings closed, 1 Important + 1 Minor open; R2 priority and its two exact carrier reproductions are closed, but the broader carrier obligation, matrix, and Minor remain open.
- Final decision: **FAIL**.
