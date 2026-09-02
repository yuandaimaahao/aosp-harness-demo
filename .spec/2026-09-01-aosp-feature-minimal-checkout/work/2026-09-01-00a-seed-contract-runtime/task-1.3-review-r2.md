# Task 1.3 fresh review R2

- Range: `5338e29d0acfc09eb12e6181bf72f9095a179044..8c4bebb50845061a57f70abe8fbf8d402d74d231`
- Immutable package: `review-5338e29d-8c4bebb5.md`
- Prior review checked: `task-1.3-review-r1.md` (2 blockers, 3 important, 1 minor).
- Scope: exactly the two permitted files. `git diff --numstat` is runtime `33/3`, test `26/1`: 59 additions, within the task ceiling of 100.
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**.
- Findings: **0 blockers, 3 important, 1 minor**.

## Standards — PASS

No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found. The diff changes public facts first, preserves the shared verifier/parity results, and `git diff --check` is clean. The compressed single-line validator/test style remains difficult to audit, but it is the established style of these two files and no repository rule forbids it; no Fowler smell is promoted to a Standards failure.

## Spec — FAIL

### I1 — `credential-free` remote validation is neither sound nor complete

At exact-head runtime line 74, a remote string is treated as credential-free exactly when it contains no `@`. This accepts an obvious credential-bearing value such as `https://example/repo?access_token=secret`, so a secret can enter canonical seed/object bytes. It also rejects a credential-free URL whose path contains an `@`, such as `https://example/repo/@scope/project`. The brief's seed manifest ABI requires each URL string to be credential-free, not globally free of the `@` character. The test at line 67 exercises only the user-info form `alice:secret@...`, so both sides of this defect are unprotected.

### I2 — normalized relative seed paths accept embedded NUL

The new manifest project and lunch validators call `_rel` at exact-head lines 75 and 85. `_rel` (line 38) checks slash/components but not `\0`; consequently both `manifest.projects[0].path="a\0b"` and `lunch.out_dir_relative="tmp/preflight/a\0b"` validate after their digests are recomputed. An embedded NUL cannot denote a filesystem path, so it is not a valid normalized relative path under the ABI. This is inconsistent with the same runtime's explicit NUL rejection for `source_root` and `repo_launcher_path` and leaves downstream path consumers with a seed that cannot be represented to filesystem APIs.

### I3 — the seed test uses the implementation as its reconstruction/digest oracle

Test lines 52–54 derive all expected request/content/identity digests by calling runtime `_seed_parts`; they independently assert only one content member and one identity member. Lines 62–64 cover five exclusion examples, but do not assert the exact three reconstructed dictionaries or systematically mutate identity-bearing fields. A wrong field inclusion/omission can therefore produce self-consistent expected digests and pass. The type-valid matrix also omits the credential query/path cases, NUL relative paths, and empty `string|null` cases below. This is partial against task step 1's required repeated-field, identity-exclusion, nested reconstruction/domain and semantic matrix, and it did not detect I1/I2/M1.

### M1 — declared `string|null` fields are narrowed to nonempty strings

The brief explicitly marks manifest URL values and lunch variable values as `string/null`; only remote `name` and lunch target/product/release/variant are declared nonempty. Runtime lines 74 and 85 nevertheless call `_text`, which rejects `""`. A seed with `TARGET_2ND_ARCH=""`, or a credential-free empty remote string, is rejected with `DESCRIPTOR_SCHEMA_INVALID` despite matching the declared type/nullability. The seed test uses only `None` for variables and only nonempty remote strings.

## R1 finding disposition

- B1 source-state truth table/count relation: **resolved**. `dirty,false,0`, `dirty,true,1`, and affected count greater than manifest project count all reject `DESCRIPTOR_SCHEMA_INVALID`; valid `dirty,false,1` remains accepted.
- B2 malformed public envelope: **resolved**. `_validate_public_real` now routes through `_validate_artifact`; wrong `schema_version` or `kind` returns `False`.
- I1 host/container nullability: **resolved**. Host plus digest rejects; container plus 64-hex digest accepts.
- I2 credential user-info example: **partially resolved**, superseded by I1 above. The prior `alice:secret@...` case rejects, but the predicate still does not implement credential-free strings correctly.
- I3 semantic matrix: **partially resolved**, superseded by I3/M1 above. The R1-specific truth-table, host/container, malformed-envelope, valid vendor and artifact-digest assertions were added, but the required independent reconstruction/type-valid matrix remains incomplete.
- M1 launcher symlink: **resolved**. A normalized absolute symlink leaf is accepted; normalization/NUL checks remain enforced.

## Executable evidence

All commands ran against an archive of exact head `8c4bebb50845061a57f70abe8fbf8d402d74d231`; no AOSP source, envsetup, lunch, build, sync, network fetch or download was used.

```sh
python3 -B common/tests/test_seed_contract_runtime.py evidence-schema seed-schema
# PASS evidence-schema
# PASS seed-schema
python3 -B common/tests/test_seed_contract_runtime.py canonical-core evidence-schema seed-schema
# PASS canonical-core
# PASS evidence-schema
# PASS seed-schema
bash common/tests/test-harness.sh
# final: RESULT PASS  shared Harness regression suite
bash common/.harness/bin/check-parity.sh
# PARITY PASS  Claude/Codex 共享同一公共契约
git diff --check 5338e29d0acfc09eb12e6181bf72f9095a179044..8c4bebb50845061a57f70abe8fbf8d402d74d231
# exit 0, no output
```

The independent semantic probe produced:

```text
dirty/false/0 REJECTED DESCRIPTOR_SCHEMA_INVALID
dirty/true/1 REJECTED DESCRIPTOR_SCHEMA_INVALID
affected>manifest REJECTED DESCRIPTOR_SCHEMA_INVALID
host+digest REJECTED DESCRIPTOR_SCHEMA_INVALID
credential-userinfo REJECTED DESCRIPTOR_SCHEMA_INVALID
credential-query ACCEPTED
credential-free-at-path REJECTED DESCRIPTOR_SCHEMA_INVALID
manifest-path-nul ACCEPTED
out-dir-nul ACCEPTED
public-schema_version False
public-kind False
empty-variable-string REJECTED DESCRIPTOR_SCHEMA_INVALID
empty-credential-free-string REJECTED DESCRIPTOR_SCHEMA_INVALID
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 0 blockers / 3 important / 1 minor.
- Worst issue: the purported credential-free check can persist obvious token-bearing remote strings in canonical artifacts.
