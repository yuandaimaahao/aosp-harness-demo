# Task 1.3 credential fuse fresh review

- Range: `7f2d97fee8705b658bea613ffda6f2f957042f53..bf1b8facb9b4e16a4487f6f6643a0cbdecd71da9`
- Immutable package: `review-7f2d97fe-bf1b8fac.md`
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**
- Findings: **0 blockers / 1 important / 1 minor**

## Standards — PASS

The exact range contains one commit and changes only the two task-owned files: runtime `5/2`, test `4/0`. `git diff --check` is clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md`, and no new review-worthy Fowler smell, was found.

## Spec — FAIL

### I1 — credential-key recognition is not actually case-insensitive

Exact-head runtime lines 39–41 derive word boundaries from the original capitalization before lowercasing. Changing only the casing can therefore erase a camel-case boundary: `PrivateToken` rejects, but `PRIVATETOKEN` accepts. The same bypass occurs for `OAUTHTOKEN`, `CLIENTSECRET`, `XAMZCREDENTIAL`, and `XAMZSIGNATURE`.

An independent full-manifest probe confirmed that every one of those credential-bearing query keys is accepted in each of `fetch_url`, `review_url`, and `mirror_url`. These values can consequently enter canonical seed/content/identity bytes. This does not satisfy the requested case-insensitive credential fuse for the private/oauth token, client-secret, and AWS credential/signature families.

The positive boundary is otherwise preserved: URL user-info rejects, while an `@` path, empty string, `null`, and `?ref=main&author=alice` accept for all three remote fields.

### M1 — the added matrix cannot catch the casing bypass

The new test is a direct, type-valid schema test across all three remote fields and would regress the prior implementation for its listed spellings. However, it tests lower/snake spellings plus delimiter-preserving `X-Amz-*`; it does not assert that changing only key casing preserves rejection. Exact-head `seed-schema` therefore passes while all I1 cases are accepted.

## Executable evidence

All commands ran from a `git archive` of exact head `bf1b8facb9b4e16a4487f6f6643a0cbdecd71da9`; no AOSP/source/build/sync/download command ran.

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
```

Independent full-manifest probe, repeated for `fetch_url`, `review_url`, and `mirror_url`:

```text
PRIVATETOKEN      ACCEPTED
OAUTHTOKEN        ACCEPTED
CLIENTSECRET      ACCEPTED
XAMZCREDENTIAL    ACCEPTED
XAMZSIGNATURE     ACCEPTED
@ path            ACCEPTED
empty             ACCEPTED
null              ACCEPTED
ref/author query  ACCEPTED
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 0 blockers / 1 important / 1 minor.
- Worst issue: casing alone can turn a rejected sensitive query-key family member into an accepted one.
