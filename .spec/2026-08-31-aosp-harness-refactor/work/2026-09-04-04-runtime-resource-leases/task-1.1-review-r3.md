# Task 1.1 incremental diff review — round 3 (fix round 2)

## Verdict

**PASS**

- Blocking: 0
- Important: 0
- Minor: 0

This is a scope-limited re-review of `23ca68fe5e3c39a25d90d92b879e215045702a99..569bb221aca20451706b0a6399683a71255bd7d1`. I read the preceding r2 finding, complete fix2 diff package, updated implementer report, and fix2 RED evidence. The review is limited to the r2 deadline-after-resume defect, wait/lock-release/error-mapping adjacency, and the requested mechanical gates.

## Findings

### Blocking

None.

### Important

None.

### Minor

None.

## ① Specification conformance

| Requirement | Result | Incremental evidence |
|---|---|---|
| R7 | ✅ | The new post-`LOCK_NB` deadline branch is before `recover_trash()` and `active_records()`. A requester with `wait=1` was stopped after retry began, resumed after both its deadline and a 1.2-second lock holder’s release, and returned `rc=3` after 1419ms with zero stdout and exact `error: resource lease unavailable\n`. A deliberately malformed pre-existing `active-bad` record remained byte-identical; if active state had been read, it would have produced rc2. No new active record was published. |
| R4/R5/R6 adjacent behavior | ✅ | No-contention `wait=0` acquire still returned 0 with a 33-byte token and empty stderr; its release returned 0 with empty streams and no residual active/tmp/trash records. A normal `wait=1` timeout against a 1.2-second holder returned rc3 with the fixed unavailable mapping, then after holder release a fresh acquire and release both returned 0 with clean streams and no residual records. This confirms the new `die(BUSY, 3)` while holding the coordination lock unwinds/close-releases it correctly. |
| R1–R3 | ✅ unchanged | The only semantic addition is the post-lock deadline guard; public surface, request/store codec, and publication scheme are unchanged in this two-line semantic diff. |

Specification conclusion: **PASS**.

## ② Quality review

- **Scope/YAGNI:** passes. Fix2 changes only `common/.harness/lib/resource-leases.sh` (`2 insertions, 2 deletions`); no unrelated provider, test, CI, or consumer work was added.
- **Verification quality:** supplied RED accurately captures the former post-deadline publish. Independent rechecks cover its stop/resume path, the no-state-read property via malformed state, no-contention wait=0, ordinary timeout/error framing, and post-timeout lock release. Assertions inspect rc, both streams, token size, record state, and state integrity rather than merely process completion.
- **Error and lock paths:** the added rc3 branch occurs before any store recovery/parse and `os.close(lock_fd)` in the enclosing `finally` releases the acquired flock; the independent follow-on acquire/release validates that behavior. No adjacent R7/error mapping regression was found.
- **Duplication/style:** the localized guard introduces no duplicated logic. `git diff --check`, fixed shfmt, ShellCheck, and Bash syntax checks pass.

Quality conclusion: **PASS**.

## Mechanical verification

- HEAD is the required `569bb221aca20451706b0a6399683a71255bd7d1`; its parent is FIX_BASE `23ca68fe5e3c39a25d90d92b879e215045702a99`.
- The worktree is clean (`git status --porcelain=v1`: 0 bytes); `git diff --check FIX_BASE HEAD` passes.
- Fix2 name-only is exactly `common/.harness/lib/resource-leases.sh`; numstat is `2  2`.
- Installed provider and approved prototype have `cmp -s` rc0, are both 336 lines, and both SHA-256 are `011d4804129420ff99b37115d8df0ebc605214fb3c1ecfc937cdbefb4ce746af`.
- Fixed gates pass: shfmt `v3.14.0` with empty `-d -i 2 -ci -bn` output, ShellCheck warning-level 0, and `bash -n` 0.
- Source surface remains exactly the two lease APIs; marker remains unset and the private seam anchor count is one.

