# Task 2.3 fresh independent locked-resolver security review R2

- Range: `770fc1ff68bb01f1dd90e6ad6ec27ffd58e6737a..d90d6199a0bce9549123e8c26761d27060b33600`
- Immutable package: `review-770fc1ff-d90d6199.md`
- Commits: `a599496 feat: add locked seed ref resolver`; `d90d619 fix: harden locked ref resolution`
- Authority: updated task 2.3 brief plus current `DECISIONS.md` stable-topology boundary
- Exact head under test: `d90d6199a0bce9549123e8c26761d27060b33600`
- Overall: **FAIL** — Standards **PASS**, Spec **FAIL**
- Findings: **1 Blocker / 2 Important / 1 Minor**

## Standards — PASS

The strict range changes only the two task-owned files. `git diff --numstat` is runtime `61/1` and test `19/1`: exactly 80 additions, satisfying the task ceiling (`80 <= 80`). `git diff --check` is clean. No hard violation of `common/AGENTS.md` or `common/.harness/common.md` was found, and no separate Fowler smell is promoted beyond the repository's established compact runtime/test style.

## Spec — FAIL

### B1 — a static special-device lock leaf is opened before it is classified

Runtime lines 214–221 open an existing `OUT_REF.lock` with `O_RDWR|O_NOFOLLOW` and call `fstat` only after `open` returns. Unlike the hardened ref/object reader, this path has neither prior `O_PATH` classification nor `O_NONBLOCK`. `O_NOFOLLOW` protects only against symlinks; opening a character or block device can have device-specific side effects or block before the resolver can return `OUT_REF_CONTRACT`.

The R5/R6 threat model explicitly includes static non-regular leaves, and R8 requires every non-regular lock leaf to fail deterministically as `OUT_REF_CONTRACT`. Classify with `O_PATH|O_NOFOLLOW`, require regular/owner/mode, then obtain an identity-matching nonblocking read/write fd before `flock`.

### I1 — deeply nested corrupt ref JSON escapes as raw `RecursionError`

Runtime lines 191–194 translate several decoder/canonicalizer failures to corruption but omit `RecursionError`. An exact-head ref containing 2,000 nested arrays caused `resolve_ref` to raise raw `RecursionError` instead of the required post-lock `REF_CORRUPT`; cleanup still closed every fd (`fd_delta=0`). The same decoder is used for primary/evidence objects.

Existing ref/object bytes that are not the exact closed canonical form belong to the `REF_CORRUPT` stage. Translate recursion failure inside `_decode` (and retain cleanup) so malformed nesting cannot escape the stable `ContractError` ABI.

### I2 — a non-contention `flock` failure is mislabeled as post-observation corruption

Runtime line 224 translates only `BlockingIOError` locally. Any other `OSError` from `flock` reaches lines 231–232, where the already-populated `nodes` list causes `REF_CORRUPT`. An injected `EIO` produced `REF_CORRUPT` while the observation log remained empty (`reads=[]`).

This violates the staged priority: `REF_CORRUPT` is available only after the lock has been acquired and ref/object observation has begun. A lock acquisition operational failure must be translated at the lock stage (or remain an unexpected runtime-internal failure), never reported as corrupt artifact data.

### M1 — the R1 negative-coverage finding is only partially closed

Test lines 157–163 now cover FIFO ref/object leaves, unsafe embedded digest names, state-before-ref priority, exact forbidden-root equality, schema-corrupt primary objects, terminal wrong-kind closure, project/count/sequence/journal failures, and unlock cleanup. They still omit assertions for a public-real positive seed, local/vendor public rejection, valid terminal closure with null completed digests, primary wrong-path digest, an independent project-digest mismatch, and an independent journal-vs-lunch mismatch. The current journal mutation sets a nonzero exit, so it would fail even if the lunch relation were absent.

Independent probes confirmed the current public-real positive, local rejection, and all-null terminal success, but these regressions are not carried by `ref-resolve`. Add independent table-driven mutations while preserving the exact 80-addition ceiling.

## R1 closure audit

- **B1 closed for ref/object leaves:** `_readat` uses `O_PATH|O_NOFOLLOW`, rejects non-regular leaves before the data open, uses `O_NONBLOCK`, and compares `(st_dev, st_ino)` before reading. FIFO ref and evidence-object cases return `REF_CORRUPT` without hanging.
- **B2 closed:** the primary artifact is schema/kind/domain/path-digest verified by `_artifact` before embedded names are extracted; every evidence digest is then constrained to 64 lower hex before `_readat`. The unsafe-path test observes only `pass` and the safe primary digest, never `../../../sentinel`.
- **I1 closed:** state validation runs before lexical ref validation; the real ref, not a synthetic sibling, is checked against state containment and forbidden roots without observing its leaf. Invalid state plus relative ref returns `STATE_DIR_CONTRACT`; exact forbidden-root ref returns `OUT_REF_CONTRACT`.
- **I2 closed for ordinary schema failures:** `_artifact` converts validator `ContractError` to `False`, and the resolver returns `REF_CORRUPT`; a canonical terminal with empty `failed_checks` is covered. I1 above records the remaining recursion translation hole.
- **I3 closed:** unlock failure is suppressed independently of fd closure; injected unlock `EIO` returns the verified object with zero fd delta.
- **M1 partial:** the added adversarial cases are material, but the independent relations listed above remain absent.

## Confirmed resolver behavior

- Keyword-only API and exact nominal return object are correct. State validation precedes lexical real-ref confinement; ref/object observation occurs only after a valid adjacent lock is acquired.
- Existing regular locks enforce effective UID and exact mode 0600; missing locks use adjacent `O_CREAT|O_EXCL|O_NOFOLLOW` and `fchmod(0600)`. Valid-fd contention is nonblocking and returns `REF_BUSY`.
- Canonical ref bytes, `env_pass -> seed`, `terminal_report -> terminal_report`, object mode 0444, domain/path/content digest, and missing-before-corrupt priority are enforced.
- Seed closure checks both source states, manifest/path/project digests, five trace counts, journal exit/sequence endpoints, and lunch exit. Terminal closure verifies every non-null completed digest against its matching kind. Public validation runs after closure; an independently constructed real/public seed passed, and a structurally valid local seed returned `PUBLIC_SCOPE_REQUIRED`.
- A valid terminal with all completed digests null resolves successfully. A 128-call concurrent probe produced only verified success or `REF_BUSY` (`9 OK`, `119 REF_BUSY`) and added only the adjacent 0600 lock.
- Failure snapshots in the committed test preserve object/ref/temp/sentinel bytes once the required lock exists. No implementation or test command accessed AOSP, ran envsetup/lunch/build/sync/fetch/package/flash, or downloaded content.

## Executable evidence

All commands ran in detached exact-head worktree `/tmp/aosp-harness-r2.7ooHUo`.

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
public-positive: OK
local-negative: PUBLIC_SCOPE_REQUIRED
terminal-null: OK
deeply nested corrupt ref: raw RecursionError; fd_delta=0
flock EIO before observation: REF_CORRUPT; reads=[]
concurrent 128 calls: 9 OK, 119 REF_BUSY; only adjacent lock added

bash common/tests/test-harness.sh
RESULT PASS  shared Harness regression suite
bash common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约
bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
RESULT PASS

git diff --check 770fc1ff68bb01f1dd90e6ad6ec27ffd58e6737a..d90d6199a0bce9549123e8c26761d27060b33600
exit 0; stdout/stderr empty
```

## Summary

- Standards: **PASS**, 0 findings.
- Spec: **FAIL**, 1 Blocker / 2 Important / 1 Minor.
- Worst Standards issue: none.
- Worst Spec issue: an existing static special-device lock can block or cause device-specific effects before the resolver classifies it as an invalid non-regular lock.
