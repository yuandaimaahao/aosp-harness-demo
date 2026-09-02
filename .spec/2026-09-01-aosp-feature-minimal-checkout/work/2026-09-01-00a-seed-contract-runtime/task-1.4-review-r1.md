# Task 1.4 fresh independent review R1

- Range: `ac37b75f9ddda61b647632c72ad2f8fbc72f8a2d..aaa5c4a13c3ae06155aab6c6f9389f4d59676dfe`
- Immutable package: `review-ac37b75f-aaa5c4a1.md`
- Commit: `aaa5c4a feat(harness): validate terminal report artifact`
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**
- Findings: **0 Blocker / 1 Important / 1 Minor**

## Standards — PASS

The exact range changes only the three task-owned files: runtime `6/3`, fixture `1/0`, test `6/1`; additions are `13 <= 55`. `git diff --check` is clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found, and the change introduces no new review-worthy Fowler smell. The compact one-line style is established in these files and is not promoted to a Standards failure.

## Spec — FAIL

### Blocker

None.

### Important

#### I1 — `summary_lines` accepts the sensitive material that the terminal schema explicitly forbids

Exact-head `common/.harness/closure/v1/lib/seed_contract_runtime.py:111-112` implements the summary constraint with a deny-regex for a few label words, calendar-date shapes, email-like strings, and multi-component absolute paths. It does not establish the semantic guarantee required by brief line 134: summary strings “不得含 timestamp、username、credential 或 source content”.

An independent exact-head probe constructed an otherwise valid `terminal_report` and replaced its sole summary line. All of the following were accepted:

```text
bare-username ACCEPT
time-only-timestamp ACCEPT
unix-timestamp ACCEPT
credential-value ACCEPT
source-content ACCEPT
```

The concrete values were respectively `alice`, `12:00:00Z`, `1788283200`, a fake `ghp_...` credential-shaped value, and `int main(void) { return 0; }`. These are direct examples of all four forbidden categories. Consequently a terminal object can persist identity/secret/source material while remaining schema-valid and content-addressed.

Required action: replace the open-ended deny-regex with a deterministic safe summary contract that can actually guarantee the exclusion (for example, a conservative closed vocabulary/template grammar derived from reason/check identifiers), or amend the spec to define an enforceable exact grammar before implementation. Add positive semantic-order/repetition cases plus negative username, multiple timestamp forms, credential families, and source-snippet cases.

### Minor

#### M1 — `terminal-golden` does not exercise the declared summary contract or terminal schema strongly enough

Exact-head `common/tests/test_seed_contract_runtime.py:87-91` has one forbidden timestamp example and five other mutations. It does not independently cover each terminal top-level/nested field's missing/type/nullability, all reason values, empty/unknown checks, the 120/121 summary boundary, allowed summary order/repetition, or the other three forbidden summary categories. Calling the older `evidence()` and `seed()` suites proves prior artifact validators still run, but it does not close these terminal-specific cells. This is partial against task step 1 / brief lines 529-535 and allowed I1 to pass the reported suite.

Required action: add a table-driven terminal matrix with independent expected outcomes and hard-coded domain/digest oracles; keep the cumulative task additions within `<=55`, returning to PLAN if that ceiling cannot accommodate the required matrix.

## Confirmed behavior

- Exact schema, nonempty/unique reason set, reason priority and ordered-subsequence behavior passed independent probes; reordered, duplicate, unknown, wrong-primary and empty lists all returned `DESCRIPTOR_SCHEMA_INVALID`.
- `completed_observation_digests` has exact keys and accepts only null or 64-lower-hex; missing/extra keys and uppercase/bad digests reject.
- Summary semantic order/repetition is preserved; 120 entries accept and 121 reject.
- All six artifact domains are present; `seed_content` and `seed_identity` remain internal and are rejected as `load_artifact` expected kinds with `ARGUMENT_ERROR`.
- Golden raw bytes are canonical JSON plus exactly one LF. Independent digest is `07ed847af333505342d14f49d28982f6bcc307984dbf928cd762b49c7872587f`.
- Golden is `evidence_class=fixture_only`; `_validate_public_real` returns false even with four true evidence flags. It does not claim real-source proof.
- Mutating `guard.trace_digest` changes the full seed artifact digest while leaving the embedded stable identity digest valid, confirming run-evidence identity exclusion for the exercised field.
- Scope contains no real-source/AOSP access or production ref creation.

## Executable evidence

All dynamic checks ran from detached exact-head worktree `/tmp/aosp-task14-review.ifP9v3`. No AOSP source was read and no `envsetup`, `lunch`, build, Repo, sync, fetch, clone, or download command was run.

```text
python3 common/tests/test_seed_contract_runtime.py seed-schema terminal-golden
PASS seed-schema
PASS terminal-golden

python3 common/tests/test_seed_contract_runtime.py canonical-core concurrent-core evidence-schema seed-schema terminal-golden
PASS canonical-core
PASS concurrent-core
PASS evidence-schema
PASS seed-schema
PASS terminal-golden

bash common/tests/test-harness.sh
RESULT PASS  shared Harness regression suite

bash common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约

bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
final: RESULT PASS

git diff --check ac37b75f9ddda61b647632c72ad2f8fbc72f8a2d..aaa5c4a13c3ae06155aab6c6f9389f4d59676dfe
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 0 Blocker / 1 Important / 1 Minor.
- Worst issue: schema-valid terminal summaries can contain each category of explicitly forbidden sensitive content.
