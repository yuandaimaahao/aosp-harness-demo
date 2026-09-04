# Task 1.1 incremental diff review — round 2 (fix round 1)

## Verdict

**FAIL**

- Blocking: 1
- Important: 0
- Minor: 0

Review scope is strictly the original R7 coordination-lock finding and the adjacent wait/lock-release/error-mapping behavior in `23cb18918583a9e3c2f19e97e4f89382c86ef7d7..23ca68fe5e3c39a25d90d92b879e215045702a99`. I read the round-1 finding, fix diff package, updated implementer report, fix RED evidence, task brief, and the required review protocol. The brief has no separate `R→E` table/E-IDs, so this report uses R1–R7 without inventing E-IDs.

## Findings

### Blocking

1. **[R7] A post-deadline acquisition can still succeed and publish, because the new nonblocking `flock` retry does not check the monotonic deadline before attempting the lock.**

   File: `common/.harness/lib/resource-leases.sh:201-204`.

   The deadline is tested only when `LOCK_NB` raises `BlockingIOError` (line 203). After a retry sleep returns late, or the requester is descheduled between the last pre-deadline collision and its next lock operation, line 201 attempts `flock` first. If the coordination lock was released after the deadline, that `flock` succeeds, the code skips line 203 entirely, scans an otherwise free store, and publishes a new active bundle. This is not the required final *at-deadline* no-sleep attempt followed by stop.

   Independent minimal reproduction used a valid private 0700 root and a separate owner holding `.lock` for 1.2 seconds. An acquire with `wait=1` was stopped after its retry loop began (at about 250ms) and resumed after both deadline and holder release. It returned `rc=0` after `1432ms`, wrote a 33-byte token with empty stderr, and left one `active-*` record. On resume it therefore published after the deadline rather than returning the required `rc=3`. A process cannot return while stopped, but it must not turn a missed deadline into a successful acquisition when resumed; ordinary scheduler delay has the same unchecked control path.

   The repair needs a deadline check before each retry lock attempt (with the explicitly required final no-sleep attempt modeled deliberately), so a lock that becomes available only after the window cannot be published. Preserve fail-closed handling for clock errors and the fixed `rc=3` unavailable mapping.

### Important

None.

### Minor

None.

## ① Specification conformance

| Requirement | Result | Incremental basis |
|---|---|---|
| R1–R6 | ✅ | The seven-line replacement only reformats private Python definitions/root creation and changes acquire’s coordination-lock primitive; it does not alter the public surface, request/record codec, bundle publication/unpublication, or facade result whitelist. The narrow adjacent acquire/release smoke below remained conformant. |
| R7 | ❌ | The original infinite/blocking lock acquire is improved for ordinary contention, but line 201 can acquire after deadline and publish. See Blocking finding 1. |

Specification conclusion: **FAIL**.

## ② Quality review

- **Scope/YAGNI:** passes. The fix commit has exactly one changed path, `common/.harness/lib/resource-leases.sh`, with `7 insertions, 7 deletions`; no unrelated 04a, consumer, CI, or test asset was added.
- **Verification quality:** the supplied RED evidence accurately demonstrates the former `wait=0` delayed success. Independent normal contention rechecks also pass: against a 1.2-second lock holder, `wait=0` returns `rc=3` in 58ms and `wait=1` returns `rc=3` in 1098ms, both with zero stdout and the exact unavailable line. These normal cases do not exercise a late wake/resume, which is why they miss the remaining boundary defect.
- **Adjacent lock release / error mapping:** an early-release positive wait succeeded; a subsequent disjoint acquire by the same owner also succeeded, both tokens were 33 bytes, both releases returned 0 with empty streams, and residual `active/tmp/trash` count was 0. Thus no additional nearby release or public error-mapping regression was observed. The post-deadline success itself remains an R7 protocol failure, not a release failure.
- **Duplication / formatting:** no new logical duplication beyond the localized retry code; `git diff --check` passes. The compressed one-line `try`/`except` edits remain accepted by the fixed formatter and ShellCheck.

Quality conclusion: **FAIL**, because the remaining R7 deadline defect is a correctness-critical error path.

## Mechanical verification

- Checked HEAD is `23ca68fe5e3c39a25d90d92b879e215045702a99`; its parent is the required FIX_BASE `23cb18918583a9e3c2f19e97e4f89382c86ef7d7`.
- Worktree is clean (`git status --porcelain=v1`: 0 bytes); `git diff --check FIX_BASE HEAD` passes.
- Installed provider and approved prototype compare equal (`cmp -s`: 0), each has exactly 336 lines, and both SHA-256 values are `437447996af65e89c19528ce3b0e9cd178b4ca01ebfd25323e91c20f23292beb`.
- Fixed static gates pass: shfmt `v3.14.0` (`-d -i 2 -ci -bn` empty/0), ShellCheck warning-level `0.11.0` (0), and `bash -n` (0).
- Source remains silent; sorted public `harness_*` functions are exactly `harness_lease_acquire` and `harness_lease_release`; session marker remains unset; seam anchor count is one.

