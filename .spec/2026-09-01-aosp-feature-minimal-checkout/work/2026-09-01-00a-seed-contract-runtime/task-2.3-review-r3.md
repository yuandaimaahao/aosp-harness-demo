# Task 2.3 fresh independent locked-resolver security review R3

- Range: `770fc1ff68bb01f1dd90e6ad6ec27ffd58e6737a..8d2a1f484470cba2020ba1ebff6d8c6275f82d67`
- Immutable package: `review-770fc1ff-8d2a1f48.md`
- Commits: `a599496 feat: add locked seed ref resolver`; `d90d619 fix: harden locked ref resolution`; `8d2a1f4 fix: harden resolver lock handling`
- Authority: task 2.3 brief plus current `DECISIONS.md` stable-topology boundary
- Exact head under test: `8d2a1f484470cba2020ba1ebff6d8c6275f82d67`
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**
- Findings: **0 Blocker / 1 Important / 0 Minor**

## Standards — PASS

The strict cumulative range changes only the two task-owned files. `git diff --numstat` is runtime `62/1` and test `18/1`, exactly 80 additions, satisfying the task ceiling (`80 <= 80`). `git diff --check` is clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found, and no separate Fowler smell is promoted beyond the repository's established compact runtime/test style.

## Spec — FAIL

### I1 — ref `schema_version:true` is accepted as numeric version 1

Runtime line 226 validates the decoded ref with `descriptor.get("schema_version") == 1` but does not require `type(...) is int`. In Python, `True == 1`, so exact-head resolution accepted canonical ref bytes containing JSON `"schema_version":true` and returned the seed object (`bool-schema-version OK`).

The locked-ref format is exact `{schema_version:1,kind,digest}`, and R3 requires bool-as-integer rejection. This malformed existing ref must reach the post-lock `REF_CORRUPT` stage. Require an exact integer type before comparing the value. The committed `ref-resolve` case mutates nesting, kind/path/content/closure relations, but has no bool-as-integer ref-envelope mutation, so the defect remains green.

## Prior-finding closure audit

- **R1 B1 / R2 B1 closed:** ref/object and lock leaves are first classified with `O_PATH|O_NOFOLLOW`; only regular lock leaves are reopened with `O_RDWR|O_NONBLOCK`, and `(st_dev, st_ino)` identity is rechecked. Static FIFO and Unix-socket lock leaves returned `OUT_REF_CONTRACT` without blocking.
- **R1 B2 closed:** the primary object is fully schema/kind/domain/path-digest validated before evidence names are extracted, and every evidence name is constrained to 64 lower hex before lookup.
- **R1 I1 closed:** state validation precedes lexical real-ref confinement; the real ref is checked for state/forbidden-root containment without observing its leaf, and ref/object reads begin only after the adjacent lock is held.
- **R1 I2 closed:** canonical schema-corrupt primary/evidence objects are translated to `REF_CORRUPT`; missing primary/evidence objects remain `ARTIFACT_MISSING`, preserving the required post-lock priority.
- **R1 I3 closed:** unlock failure is suppressed independently of closing every directory/lock fd; nominal and deep-corrupt probes had zero fd delta.
- **R2 I1 closed:** `_decode` catches `RecursionError`; a 2,000-level nested ref returned `REF_CORRUPT` with `fd_delta=0`.
- **R2 I2 closed:** a non-contention `flock` EIO returned lock-stage `OUT_REF_CONTRACT`, observed no ref/object names (`reads=[]`), and did not leak fds.
- **R2 M1 closed for the listed relations:** the cumulative test now carries public-real positive, fixture/local-vendor rejection, all-null and non-null terminal success, terminal wrong-kind closure, primary wrong-path digest, project digest/path/count, trace count/sequence, journal exit, and journal-vs-lunch checks. An independent missing-evidence probe returned `ARTIFACT_MISSING`.

## Confirmed behavior

- The API remains keyword-only with the exact signature and returns the verified primary dict. Lock mode 0600, effective-UID ownership, no-follow opening, nonblocking contention (`REF_BUSY`), lock-before-observation, and finally cleanup are enforced.
- Ref/object leaves are read identity-safely and nonblocking. Canonical bytes, kind mapping, object mode 0444, domain/path/content digests, safe evidence names, missing-before-corrupt priority, and final public priority are enforced apart from I1.
- Seed closure verifies both source states, manifest digest/path/project relations, five trace counts, six journal exits and sequence endpoints, and the lunch relation. Terminal closure validates every non-null completed digest against its required kind; all-null terminal reports resolve. Public-real succeeds only after structural and evidence closure.
- A 128-call exact-head concurrency probe produced only verified success or `REF_BUSY` (`8 OK`, `120 REF_BUSY`). No real AOSP path was inspected and no envsetup, lunch, build, sync, fetch/clone, package, flash, or download operation ran.

## Executable evidence

All dynamic checks ran from detached exact-head worktree `/tmp/aosp-harness-r3.oNkBbN`.

```text
python3 common/tests/test_seed_contract_runtime.py ref-resolve
PASS ref-resolve

python3 common/tests/test_seed_contract_runtime.py canonical-core concurrent-core evidence-schema seed-schema terminal-golden state-paths store-object ref-resolve
PASS canonical-core
PASS concurrent-core
PASS evidence-schema
PASS seed-schema
PASS terminal-golden
PASS state-paths
PASS store-object
PASS ref-resolve

independent exact-head probes
deep-ref REF_CORRUPT fd_delta 0
fifo-lock OUT_REF_CONTRACT
socket-lock OUT_REF_CONTRACT
flock-eio OUT_REF_CONTRACT reads []
bool-schema-version OK
concurrency {'OK': 8, 'REF_BUSY': 120}
missing-evidence ARTIFACT_MISSING

bash common/tests/test-harness.sh
RESULT PASS  shared Harness regression suite
bash common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约
bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
RESULT PASS

git diff --check 770fc1ff68bb01f1dd90e6ad6ec27ffd58e6737a..8d2a1f484470cba2020ba1ebff6d8c6275f82d67
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 0 Blocker / 1 Important / 0 Minor.
- Worst Standards issue: none.
- Worst Spec issue: bool-as-integer comparison accepts a ref envelope that violates the exact closed schema.
