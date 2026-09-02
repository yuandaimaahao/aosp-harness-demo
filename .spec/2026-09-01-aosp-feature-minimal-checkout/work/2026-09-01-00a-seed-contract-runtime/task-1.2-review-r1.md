# Task 1.2 Fresh Diff Review R1

## Scope and verdict

- Base: `b9d61b7ae681b56a8b2c1caea833ebf165988d16`
- Head: `67cc360f5bcc7c249a4804a54b9f8ec1b5316997`
- Reviewed immutable package: `review-b9d61b7a-67cc360f.md`
- Commit: `67cc360 feat(harness): validate evidence schemas`
- Overall: **FAIL**
- Standards: **PASS with 1 Minor judgement-call smell**; no documented repository-standard breach found.
- Spec: **FAIL**; 2 Blocker and 3 Important findings.

## Findings

### Blocker

1. Closed type validation accepts integers as booleans and a boolean as `schema_version`.
   - Evidence: `seed_contract_runtime.py:39,80-83` uses Python equality/dict equality. At exact head, public `load_artifact` accepted JSON with `"schema_version": true`, `public_aosp_baseline: 0`, and `vendor_context: 1`.
   - Violates: R3's bool-as-integer rejection and the exact `schema_version:1` / boolean `source_scope` schema.
   - Impact: non-conforming request artifacts enter canonical digest and downstream evidence/identity processing as valid.
   - Required action: type-check schema version with `type(...) is int` and scope flags with `type(...) is bool`; add public-load negative tests for both directions (`true` as integer, `0/1` as boolean) and assert the prescribed `ContractError` code.

2. Required per-project source-state domain dispatch is missing.
   - Evidence: `seed_contract_runtime.py:26` contains only request/workspace/trace/journal domains; no `aosp-harness/project-source-state/v1\0` entry or equivalent dispatch exists. `_project` at lines 47-51 validates fields but cannot select/return the required project domain.
   - Violates: task interface requiring request/project/workspace/trace/journal domain dispatch and Stable data ABI's per-project digest.
   - Impact: the declared `evidence-validation/v1` capability cannot provide the project digest needed for later manifest/project relations.
   - Required action: add the exact project domain to the validator/domain dispatch and test its literal separator and digest independently of runtime-owned constants.

### Important

3. A malformed command-journal record escapes as `AttributeError`, not `ContractError("DESCRIPTOR_SCHEMA_INVALID")`.
   - Evidence: `seed_contract_runtime.py:78` calls `r.get` before proving `r` is a dict. Exact-head probes with `records:[0]` and `records:[[]]` both returned `AttributeError: ... has no attribute 'get'`.
   - Violates: R3 closed-schema rejection and R12's deterministic expected-failure carrier/error behavior.
   - Impact: a normal invalid descriptor can be misreported downstream as `RUNTIME_INTERNAL`.
   - Required action: validate each record's dict/exact-key shape before stage extraction; add public `load_artifact` cases for scalar/list/null records and assert `DESCRIPTOR_SCHEMA_INVALID`.

4. `seed_request.source_root` is not required to equal its normalized realpath.
   - Evidence: `seed_contract_runtime.py:53-54` only checks leading `/` and literal `.`/`..` components. Exact-head probes accepted `/src//tree/`, `//src`, and a temporary symlink path whose `realpath` was a different string.
   - Violates: Stable data ABI's “absolute realpath string” requirement.
   - Impact: multiple/non-canonical or symlink spellings of the same source can enter request digests.
   - Required action: reject unless the absolute string is normalized and equals `realpath`; cover repeated/trailing separators and a temporary symlink without reading AOSP.

5. `evidence-schema` is far below the mandated per-field test matrix and contains a tautological domain assertion.
   - Evidence: `test_seed_contract_runtime.py:35-44` supplies four positive fixtures and only four negative mutations. It does not cover each field's missing/unknown/type/nullability, safe bounds, invalid base64/enums, both sorted-array duplicate/out-of-order cases, trace sequence order, or project domain. Line 42 reads `_DOMAINS` from the implementation on both sides, so a wrong literal domain passes.
   - Violates: task step 1 (“逐字段覆盖四 kinds、sorted/semantic arrays、base64、enum、signed/unsigned safe bounds 与 domain digest”).
   - Impact: findings 1-4 all pass the reported suite.
   - Required action: replace the four ad-hoc mutations with table-driven field/boundary/order mutations and hard-coded domain/digest oracles while keeping the task diff within 75 additions.

### Minor

6. Possible **Mysterious Name** / readability smell (judgement call only).
   - Evidence: `seed_contract_runtime.py:27-39` introduces `_bad`, `_u`, `_i`, `_rel`, `_scope`, and many semicolon-packed side-effect statements/list comprehensions.
   - Impact: type/order guards are difficult to audit, and the journal pre-validation bug is obscured by the compressed control flow.
   - Suggested action: use descriptive validator names and explicit statements; this is not a documented-standard hard violation.

## Verification evidence

- Exact-head isolated export, no AOSP source read and no prohibited AOSP/sync/download command run.
- `PYTHONDONTWRITEBYTECODE=1 python3 common/tests/test_seed_contract_runtime.py canonical-core evidence-schema` -> exit 0; exact two PASS lines; stderr empty.
- `PYTHONDONTWRITEBYTECODE=1 python3 common/tests/test_seed_contract_runtime.py concurrent-core` -> exit 0; `PASS concurrent-core`; stderr empty.
- `git diff --check b9d61b7a...67cc360f` -> exit 0; no output.
- File scope: PASS; only the two task-listed files changed.
- Budget: PASS at the hard boundary; `75` additions / `3` deletions (`60/1` runtime, `15/2` tests), so new additions are exactly `75 <= 75`.
- Red evidence exists and records the intended missing-validator failure; the task report's stated green commands are reproducible, but they are not strong enough to establish the requested capability.

## Summary

- Standards findings: 1 Minor; worst is a judgement-call readability smell.
- Spec findings: 2 Blocker, 3 Important; worst are acceptance of non-exact boolean/integer types and missing project digest domain dispatch.
- Final decision: **FAIL**.
