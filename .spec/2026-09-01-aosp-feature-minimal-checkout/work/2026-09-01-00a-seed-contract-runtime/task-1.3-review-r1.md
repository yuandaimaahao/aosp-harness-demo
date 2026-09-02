# Task 1.3 fresh review R1

- Range: `5338e29d0acfc09eb12e6181bf72f9095a179044..6afe239296bf244c97087a92f7cbfdc6bbbf89b9`
- Immutable package: `review-5338e29d-6afe2392.md`
- Scope: exactly two permitted files; `git diff --numstat` = runtime `33/3`, test `20/1` (53 additions, 4 deletions), so additions are within the task limit of 100.
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**.

## Standards — PASS

No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found in the scoped diff. On an exact-head archive, `git diff --check`, the old shared harness regression, and parity all passed. No baseline smell is promoted to a standards failure; the compressed validator style is difficult to audit, but it is already the surrounding module's convention and the repository documents no conflicting Python style rule.

## Spec — FAIL

### B1 — invalid source-state/project relations are accepted

The predicate added at immutable-diff lines 72–73 only checks
`(state == "clean") == (proof and count == 0)`. For `dirty`, this accepts any tuple for which the right side is false, including both `dirty,false,0` and `dirty,true,1`. It also never checks the required manifest/source-state count relation, so a one-project manifest accepts `affected_project_count=2`. This violates brief lines 123 and 130 and means malformed source evidence can receive valid content/identity digests instead of `DESCRIPTOR_SCHEMA_INVALID`.

### B2 — the public-real predicate accepts a non-seed envelope

Immutable-diff lines 84–87 call `_seed(payload)` directly, but `_seed` checks only the top-level key set, not the fixed values `schema_version=1` and `kind="seed"`; those checks exist only in `_validate_artifact`. Consequently, after recomputing a valid public seed, changing either field to `schema_version=2` or `kind="not-seed"` still makes `_validate_public_real(..., all_true_evidence)` return `True`. The pure seam therefore violates the closed seed schema and the requirement that public scope is evaluated only for a structurally successful seed (brief lines 112, 130, and 510).

### I1 — host execution incorrectly permits a container digest

At immutable-diff lines 65–66, the host/container expression has no terminal `or _bad()`. A host artifact with a non-null 64-hex `container_digest` falls through successfully, contrary to brief lines 120 and 126. Because this field is carried into `execution_identity`, the implementation can mint a valid identity digest for a forbidden execution representation.

### I2 — credential-bearing manifest remotes are accepted

Immutable-diff lines 58–60 apply only `_text` to `fetch_url`, `review_url`, and `mirror_url`. An obvious user-info URL such as `https://alice:secret@example/repo` validates. This violates the explicit credential-free requirement at brief line 118 and risks persisting credentials in canonical seed/object bytes.

### I3 — `seed-schema` does not exercise the required semantic matrix

The generic loop at immutable-diff lines 124–130 mostly substitutes `{}`, so it cannot catch type-correct but relation-invalid values. The public “vendor” negative at line 135 is itself an invalid scope combination (`public_aosp17_cuttlefish` plus `vendor_context=true`), rather than a structurally valid real-source local/vendor seed. The suite also does not assert malformed public envelopes, dirty-state truth-table cases, affected-count bounds, host/container nullability, credential-free remotes, or that excluded run-evidence mutations change the artifact digest while leaving content/identity unchanged. Thus brief line 512's repeated-field/identity/success/public fixture-local-vendor coverage is partial, and the passing test does not protect B1–I2.

### M1 — `repo_launcher_path` is stricter than the declared ABI

Immutable-diff lines 63–64 require `path == realpath(path)`, which rejects an otherwise normalized absolute path whose leaf is a symlink. Brief line 119 requires only a normalized absolute launcher path; unlike `source.root`, it does not require realpath equality. This can reject legitimate launcher observations (for example a symlinked `repo` executable).

## Executable evidence

Exact-head non-AOSP checks:

```sh
REVIEW_SNAPSHOT=$(mktemp -d /tmp/aosp-harness-task13-review.XXXXXX)
git archive 6afe239296bf244c97087a92f7cbfdc6bbbf89b9 common | tar -x -C "$REVIEW_SNAPSHOT"
cd "$REVIEW_SNAPSHOT"
python3 -B common/tests/test_seed_contract_runtime.py evidence-schema seed-schema
python3 -B common/tests/test_seed_contract_runtime.py canonical-core evidence-schema seed-schema
bash common/tests/test-harness.sh
bash common/.harness/bin/check-parity.sh
```

Observed exact success lines: `PASS evidence-schema`, `PASS seed-schema`; then `PASS canonical-core`, `PASS evidence-schema`, `PASS seed-schema`; `RESULT PASS  shared Harness regression suite`; `PARITY PASS  Claude/Codex 共享同一公共契约`. Stderr was empty. `git diff --check 5338e29d..6afe2392` also exited 0 with empty output.

The following supplemental probe imports the exact-head runtime, captures the valid seed built by `test_seed_contract_runtime.seed`, recomputes request/content/identity digests after each mutation, and calls `_validate_artifact` / `_validate_public_real`:

```sh
PYTHONPATH=common/.harness/closure/v1/lib:common/tests python3 -B - <<'PY'
import copy
import seed_contract_runtime as r, test_seed_contract_runtime as t
seen=[]; original=r._validate_artifact
def capture(value):
    if not seen: seen.append(copy.deepcopy(value))
    return r._DOMAINS['seed']
r._validate_artifact=capture
try: t.seed()
except AssertionError: pass
finally: r._validate_artifact=original
base=seen[0]
def finish(value):
    request,content,identity=r._seed_parts(value)
    value['request_digest']=r.domain_digest(domain_ascii=r._DOMAINS['seed_request'],value=request)
    value['seed_content_digest']=r.domain_digest(domain_ascii=r._DOMAINS['seed_content'],value=content)
    identity['seed_content_digest']=value['seed_content_digest']
    value['seed_identity_digest']=r.domain_digest(domain_ascii=r._DOMAINS['seed_identity'],value=identity)
def check(label,value):
    finish(value)
    try: original(value)
    except r.ContractError as error: print(label,'REJECTED',error.code)
    else: print(label,'ACCEPTED')
s=copy.deepcopy(base); s['source_state'].update(state='dirty',clean_source_proof=False,affected_project_count=0); check('dirty/false/0',s)
s=copy.deepcopy(base); s['source_state'].update(state='dirty',clean_source_proof=True,affected_project_count=1); check('dirty/true/1',s)
s=copy.deepcopy(base); s['source_state'].update(state='dirty',clean_source_proof=False,affected_project_count=2); check('affected>manifest',s)
s=copy.deepcopy(base); s['execution']['container_digest']='1'*64; check('host+digest',s)
s=copy.deepcopy(base); s['manifest']['remotes']=[{'name':'r','fetch_url':'https://alice:secret@example/repo','review_url':None,'mirror_url':None}]; check('credential URL',s)
p=copy.deepcopy(base); p.update(evidence_class='real_source',source_scope={'role':'public_aosp17_cuttlefish','public_aosp_baseline':True,'vendor_context':False,'platform_family':'aosp-17'}); finish(p)
e=dict.fromkeys(('source_state_before','source_state_after','trace','command_journal'),True)
for key,value in [('schema_version',2),('kind','not-seed')]:
    q=copy.deepcopy(p); q[key]=value; print('public '+key,r._validate_public_real(q,e))
PY
```

Its exact output was:

```text
dirty/false/0 ACCEPTED
dirty/true/1 ACCEPTED
affected>manifest ACCEPTED
host+digest ACCEPTED
credential URL ACCEPTED
public schema_version True
public kind True
```

An independent path probe passed a temporary absolute symlink as `repo_launcher_path`; `_tools` returned `DESCRIPTOR_SCHEMA_INVALID`, confirming M1.

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 2 blockers, 3 important, 1 minor. Worst issues are acceptance of contradictory source-state evidence and a malformed envelope by the public-real trust predicate.
