# Task 1.2 Fresh Diff Review R2

## Scope and verdict

- Base: `b9d61b7ae681b56a8b2c1caea833ebf165988d16`
- Head: `5337b6dd27b198403b2e6db16ecf44edad2844bc`
- Reviewed immutable package: `review-b9d61b7a-5337b6dd.md`
- Commits: `67cc360 feat(harness): validate evidence schemas`; `5337b6d fix(harness): tighten evidence validation`
- Overall: **FAIL**
- Standards: **PASS with 1 Minor judgement-call smell**; no documented repository-standard breach found.
- Spec: **FAIL**; 3 Important findings, no Blocker.

## Findings

### Blocker

None.

### Important

1. Correctly shaped public calls can still escape the required `ContractError` carrier.
   - Evidence: `seed_contract_runtime.py:81` uses `.get(v.get("kind"), _bad)(v)`, but `_bad` accepts no argument. A public `load_artifact(path=..., expected_kind="bogus")` over `{"schema_version":1,"kind":"bogus"}` raises raw `TypeError: _bad() takes 0 positional arguments but 1 was given`, not the bound-value `ContractError("ARGUMENT_ERROR")` required by Runtime API/R12.
   - Evidence: `seed_contract_runtime.py:53` calls `os.path.realpath` without translating value errors. A seed request whose `source_root` is `"/tmp/a\u0000b"` raises raw `ValueError: embedded null byte`, rather than rejecting the malformed realpath string as `ContractError("DESCRIPTOR_SCHEMA_INVALID")`.
   - Impact: later wrappers translate these ordinary invalid inputs to `RUNTIME_INTERNAL`, violating the unique expected-failure carrier and deterministic code contract.
   - Executable probe, run against an archive of exact head with that archive's runtime on `PYTHONPATH`, produced:
     ```text
     unknown-kind TypeError None '_bad() takes 0 positional arguments but 1 was given'
     nul-source-root ValueError None 'embedded null byte'
     ```
   - Required action: validate the accepted `expected_kind` value before I/O/dispatch, invoke the fallback without an incompatible argument, and translate invalid path-string failures to the prescribed `ContractError`; add public-entry tests for both cases.

2. `load_artifact` violates the fixed error priority when unsupported schema is mixed with lower-priority defects.
   - Evidence: `seed_contract_runtime.py:90-92` runs recursive `_guard` and expected-kind comparison before `_validate_artifact` checks schema version at lines 79-80.
   - Exact-head probes returned `DESCRIPTOR_SCHEMA_INVALID` for both `(schema_version=2 + expected-kind mismatch)` and `(schema_version=2 + float field)`. R12 orders `UNSUPPORTED_SCHEMA_VERSION` before `DESCRIPTOR_SCHEMA_INVALID`, so both must stop at `UNSUPPORTED_SCHEMA_VERSION`.
   - Executable probe shape: write a valid request JSON, set `schema_version=2`, then respectively set `kind="trace"` while calling `expected_kind="seed_request"`, or set `estimated_disk_upper_bound_bytes=1.5`; call public `load_artifact` and inspect `ContractError.code`.
   - Required action: after UTF-8/JSON/duplicate-key processing, establish exact integer schema version and reject unsupported versions before recursive scalar/schema/kind validation; add mixed-fault assertions.

3. R1 Important #5 remains open: `evidence-schema` is still not the mandated per-field matrix.
   - Evidence: `test_seed_contract_runtime.py:44-45` has 23 negative mutations, but does not cover every top-level/nested field's missing/unknown/type/nullability across all four kinds.
   - Missing matrix cells include: out-of-order `projects`/`entries`, duplicate and out-of-order trace sequences, duplicate semantic `paths` with order preservation, most base64 fields (`status_record_b64`, trace argv/path, journal argv/cwd), most enums (`entry_kind`, path role, address family), negative unsigned values and per-field safe-bound acceptance/rejection, and digest-change assertions for field mutations.
   - The hard-coded request/project/workspace/trace/journal domain literals at lines 42-43 are now non-tautological and correct, but one positive digest equation per payload does not satisfy “逐字段覆盖”.
   - Executable evidence: `git show 5337b6dd:common/tests/test_seed_contract_runtime.py | nl -ba | sed -n '32,45p'` displays the entire matrix above.
   - Impact: the reported green suite cannot establish the task's explicit test deliverable and did not expose findings 1-2.
   - Required action: replace the selective mutation tuple with table-driven per-field/boundary/order/carrier cases while preserving the cumulative `<=75` additions ceiling; if that cannot fit, return to PLAN rather than omitting the matrix.

### Minor

4. Possible **Mysterious Name** / readability smell (judgement call only) remains.
   - Evidence: `seed_contract_runtime.py:27-81` retains `_bad`, `_u`, `_i`, `_rel`, `_state` and many semicolon-packed side-effect expressions/list comprehensions.
   - Impact: validation order and exception paths are hard to audit; findings 1-2 are obscured by this compression.
   - Suggested action: prefer descriptive validators and explicit control flow if the approved line budget is revised. No documented repository standard forbids the current style.

## R1 closure audit

| R1 finding | R2 status | Evidence |
|---|---|---|
| Blocker 1: bool/int type confusion | **Closed** | Exact `type(... ) is int/bool` checks at runtime lines 29-30, 39, 79; public negative cases at test line 44 pass. |
| Blocker 2: missing project domain | **Closed** | Exact `aosp-harness/project-source-state/v1\0` at runtime line 26; `_project` dispatch at line 50; hard-coded oracle at test line 43. |
| Important 3: malformed journal escapes | **Closed** | Record exact-shape prevalidation at runtime line 75; scalar/list/null public cases at test line 44 pass as `DESCRIPTOR_SCHEMA_INVALID`. |
| Important 4: source root not exact realpath | **Closed for the reported cases** | Equality with `os.path.realpath` at runtime line 53; repeated separator, `//`, and symlink cases at test line 44 pass. The newly found NUL carrier defect is finding 1. |
| Important 5: required test matrix missing | **Open** | Expanded from 4 to 23 negative mutations, but remains selective rather than per-field; see finding 3. |
| Minor 6: compressed validator readability | **Open** | Same compact naming/control-flow style remains; see finding 4. |

## Verification evidence

- Exact-head isolated archive only; no real AOSP path was read and no prohibited AOSP/sync/download command was run.
- `PYTHONDONTWRITEBYTECODE=1 python3 common/tests/test_seed_contract_runtime.py canonical-core evidence-schema` -> exit 0; exact two PASS lines; stderr empty.
- `PYTHONDONTWRITEBYTECODE=1 python3 common/tests/test_seed_contract_runtime.py concurrent-core` -> exit 0; `PASS concurrent-core`; stderr empty.
- Independent malformed-input probes reproduced findings 1-2 as described above.
- `git diff --check b9d61b7a..5337b6dd` -> exit 0; no output.
- File scope: PASS; only the two task-listed files changed.
- Budget: PASS at the hard boundary; `75` additions / `3` deletions (`59/1` runtime, `16/2` tests), so additions are exactly `75 <= 75`.
- Red evidence exists and records the intended `evidence validators missing` failure.
- Exact-head isolated regressions: parity exact PASS; dev-sidebar demo ends `RESULT PASS`; shared harness suite ends `RESULT PASS  shared Harness regression suite`.

## Summary

- Standards findings: 1 Minor; worst is the judgement-call readability smell.
- Spec findings: 3 Important, 0 Blocker; worst is ordinary invalid data escaping the stable error carrier.
- Prior R1: 2 Blocker + 2 Important closed; 1 Important + 1 Minor remain open.
- Final decision: **FAIL**.
