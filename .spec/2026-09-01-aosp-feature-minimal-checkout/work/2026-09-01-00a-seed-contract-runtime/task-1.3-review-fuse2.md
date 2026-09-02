# Task 1.3 credential fuse correction fresh review

- Range: `bf1b8facb9b4e16a4487f6f6643a0cbdecd71da9..ac37b75f9ddda61b647632c72ad2f8fbc72f8a2d`
- Immutable package: `review-bf1b8fac-ac37b75f.md`
- Overall: **PASS**
- Findings: **0 blockers / 0 important / 0 minor**

## Findings

None.

## Standards — PASS

The exact range contains one commit and changes only the two task-owned files: runtime `2/2`, test `1/1`. `git diff --check` is clean. The correction introduces no hard violation of `common/AGENTS.md` or `common/.harness/common.md`, and no review-worthy Fowler smell.

## Spec — PASS

Exact-head runtime lines 39–41 now lowercase the complete query key before removing every non-ASCII-alphanumeric separator. The resulting compact key is matched against the sensitive token, secret, credential, signature, password, passwd, and API-key families, with exact auth/authorization/authentication/oauth handling. `_url` applies this predicate to parsed query keys, and `_manifest` applies `_url` uniformly to `fetch_url`, `review_url`, and `mirror_url`.

Exact-head test lines 78–81 add upper-, mixed-, and separator-free variants for the five families that bypassed the previous implementation, across all three remote fields. The same matrix retains the non-sensitive `ref`/`author` acceptance check.

An independent full-seed reconstruction probe exercised each of the three remote fields and confirmed:

- 81/81 sensitive query cases reject with `DESCRIPTOR_SCHEMA_INVALID`: upper/mixed case plus separator-free and separated private-token, oauth-token, client-secret, X-Amz-Credential, and X-Amz-Signature variants, including percent-decoded separators.
- 12/12 positive boundary cases accept: an `@` path, empty string, `null`, and `?ref=main&author=alice`, for every remote field.
- URL user-info rejects for all three remote fields.

The prior case-insensitivity bypass is therefore closed without regressing the required accepted boundary.

## Executable evidence

All commands ran from a `git archive` of exact head `ac37b75f9ddda61b647632c72ad2f8fbc72f8a2d`. No AOSP/source/build/sync/download operation ran.

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

independent full-seed credential matrix
PASS independent credential fuse matrix

git diff --check bf1b8facb9b4e16a4487f6f6643a0cbdecd71da9..ac37b75f9ddda61b647632c72ad2f8fbc72f8a2d
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **PASS**, 0 blockers / 0 important / 0 minor.
- Direct regression: **PASS**.
