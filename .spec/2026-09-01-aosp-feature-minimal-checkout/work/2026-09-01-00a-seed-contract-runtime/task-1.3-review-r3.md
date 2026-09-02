# Task 1.3 fresh review R3

- Range: `5338e29d0acfc09eb12e6181bf72f9095a179044..7f2d97fee8705b658bea613ffda6f2f957042f53`
- Immutable package: `review-5338e29d-7f2d97fe.md`
- Prior reviews: `task-1.3-review-r1.md`, `task-1.3-review-r2.md`
- Scope: exactly the two permitted files. `git diff --numstat` is runtime `41/5`, test `35/2`: 76 additions, within the task ceiling of 100.
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**.
- Findings: **0 blockers, 1 important, 1 minor**.

## Standards — PASS

No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found. The cumulative diff stays in the two task-owned files, changes the public runtime before its test consumer, preserves parity/shared regression, and is clean under `git diff --check`. The dense one-line validator/test style is difficult to audit, but it is the pre-existing convention in these files and no repository rule overrides it; no Fowler smell is promoted to a Standards failure.

## Spec — FAIL

### I1 — the credential-free predicate still accepts common credential-bearing remote URLs

Exact-head runtime line 44 rejects only URL user-info and a small query-key denylist. It accepts standard credential-bearing forms whose query keys are absent from that list, including `?private_token=secret`, `?oauth_token=secret`, `?client_secret=secret`, and AWS presigned `?X-Amz-Credential=...&X-Amz-Signature=...`. These strings are then included in canonical seed/content/identity bytes. This leaves R2 I1 only partially resolved and violates the seed manifest requirement that all three remote URL fields be credential-free (brief line 118). This is not a merely theoretical arbitrary query: the accepted names are established credential parameter names.

### M1 — the credential semantic matrix tests only one query spelling

Exact-head test line 73 covers user-info and `access_token`, while line 76 covers only the prior false-positive `@` path and empty string. It has no type-valid negative cases for other common token/secret/signature query keys, so `seed-schema` passes while I1 remains. The independent request/content/identity oracle added at lines 52–57 is otherwise sound and closes R2 I3; this finding is limited to the task step 1 credential semantic matrix.

## Prior finding disposition

- R1 B1 source-state truth table/count relation: **resolved**. All contradictory tuples and count greater than manifest projects reject; valid `dirty,false,1` accepts.
- R1 B2 malformed public envelope: **resolved**. Public seam validates the full artifact; wrong schema/kind returns false.
- R1 I1 host/container nullability: **resolved**.
- R1/R2 credential-free remotes: **partially resolved**, superseded by I1. User-info and `access_token` reject; `@` path and empty string accept, but the common credential forms above also accept.
- R1 I3 / R2 I3 semantic matrix and independent reconstruction oracle: **resolved except M1**. The test now independently spells the exact three dictionaries and domains, verifies runtime reconstruction equality, checks identity-bearing and excluded mutations, success relations, and fixture/local/public evidence summaries.
- R1 M1 launcher symlink: **resolved**. The validator requires normalized absolute syntax without realpath equality.
- R2 I2 relative-path NUL: **resolved** for manifest project and lunch OUT_DIR.
- R2 M1 `string|null` empty values: **resolved** for remote URL strings and lunch variables.

## Full task 1.3 coverage

- Closed seed/nested schemas, enums/nullability/safe integers, relative paths, host/container relation, resource equations, clean/dirty relation, manifest count relation, success invariants, exact request/content/identity reconstruction, all three domains, artifact domain dispatch, and `load_artifact(..., expected_kind="seed")`: present.
- Identity-bearing fields and excluded run-evidence mutations: independently exercised; excluded mutations change the full artifact digest while preserving content/identity.
- `_validate_public_real(payload, evidence)`: pure boolean seam, validates the full seed first, distinguishes fixture/local/public, requires the exact four all-true evidence keys, and uses `ContractError` as the expected validator carrier.
- Credential-free semantics: **incomplete per I1**.
- Scope/budget: two permitted files only; 76 additions, no AOSP/envsetup/lunch/build/sync/download execution.

## Executable evidence

All probes ran against `git archive 7f2d97fee8705b658bea613ffda6f2f957042f53`; no real AOSP/source command or network operation was used.

```text
python3 -B common/tests/test_seed_contract_runtime.py evidence-schema seed-schema
PASS evidence-schema
PASS seed-schema

python3 -B common/tests/test_seed_contract_runtime.py canonical-core evidence-schema seed-schema
PASS canonical-core
PASS evidence-schema
PASS seed-schema

bash common/tests/test-harness.sh
RESULT PASS  shared Harness regression suite

bash common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约

git diff --check 5338e29d0acfc09eb12e6181bf72f9095a179044..7f2d97fee8705b658bea613ffda6f2f957042f53
# exit 0, no output
```

Independent exact-head credential/path/nullability probe:

```text
userinfo REJECTED DESCRIPTOR_SCHEMA_INVALID
access_token REJECTED DESCRIPTOR_SCHEMA_INVALID
private_token ACCEPTED
oauth_token ACCEPTED
client_secret ACCEPTED
aws_credential ACCEPTED
credential_free_at_path ACCEPTED
empty_remote ACCEPTED
manifest_nul REJECTED DESCRIPTOR_SCHEMA_INVALID
outdir_nul REJECTED DESCRIPTOR_SCHEMA_INVALID
empty_variable ACCEPTED
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 0 blockers / 1 important / 1 minor.
- Worst issue: common credential-bearing remote URLs can still be persisted into canonical seed/content/identity artifacts.
