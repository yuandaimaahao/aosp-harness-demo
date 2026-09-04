# Task 1.1 — resource lease runtime provider

Status: DONE

- BASE: `692d52d00b56df9609760aa33a6f9aa3c38095a3`
- HEAD / task commit: `23cb18918583a9e3c2f19e97e4f89382c86ef7d7` — `feat(harness): add resource lease runtime`
- Changed file: `common/.harness/lib/resource-leases.sh` only.
- BASE..HEAD numstat: `336  0  common/.harness/lib/resource-leases.sh`; name-only is exactly that one file.

RED evidence: before installation, `cmp -s common/.harness/lib/resource-leases.sh "$SPEC/prototypes/common/.harness/lib/resource-leases.sh"` returned `2`; the target was absent, the approved prototype existed, and stdout/stderr were both empty. Saved in `evidence/task-1.1-red.txt`.
红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.1-red.txt

GREEN / static evidence:

- The same `cmp -s` returned `0`; line count was `336`.
- `/tmp/aosp-harness-tools-04/shfmt --version` reported `v3.14.0`; `/tmp/aosp-harness-tools-04/shfmt -d -i 2 -ci -bn common/.harness/lib/resource-leases.sh` returned `0` with empty output.
- `/tmp/aosp-harness-tools-04/shellcheck --version` reported version field `0.11.0`; `/tmp/aosp-harness-tools-04/shellcheck -x --severity=warning common/.harness/lib/resource-leases.sh` returned `0` with empty output.
- `bash -n common/.harness/lib/resource-leases.sh` returned `0`.
- In an isolated Bash, sourcing returned `0`, with both `evidence/task-1.1-source.out` and `.err` at 0B. Sorted `harness_*` functions are exactly `harness_lease_acquire` and `harness_lease_release`; `HARNESS_SESSION_STATE_PROVIDER_VERSION` remains unset; `HARNESS_RESOURCE_LEASE_TEST_SEAM` occurs once.

Full command results are in `evidence/task-1.1-static.log`; delivery summary is `evidence/task-1.1-package.tsv`.

The implementation worktree is clean (`git status --porcelain=v1` produced 0 bytes).

Concerns: none. Per controller direction, no review, manifest, ledger, or later-task asset was created by this task.

## Fix round 1 — R7 bounded coordination-lock acquisition

- Fix BASE: `23cb18918583a9e3c2f19e97e4f89382c86ef7d7`
- Fix HEAD / commit: `23ca68fe5e3c39a25d90d92b879e215045702a99` — `fix(harness): bound resource lease lock wait`
- Worktree change: `common/.harness/lib/resource-leases.sh` only (`7` insertions, `7` deletions); the approved prototype at `specs/2026-09-04-04-runtime-resource-leases/prototypes/common/.harness/lib/resource-leases.sh` was updated identically.

Fix RED reproduced the reviewer scenario before repair: a separate live Python owner held the valid state-root `.lock` for 1.2 seconds while `harness_lease_acquire review-session 0 request.tsv` ran. The pre-fix command returned `0` after `1216ms`, with a 33-byte token stdout and 0B stderr, rather than promptly returning unavailable. The exact evidence is `evidence/task-1.1-fix1-red.txt`.

Fix GREEN used the same held-lock scenario after repair. `wait=0` returned `3` in `66ms`, stdout was 0B, and stderr SHA-256 was `e30e607273b999dc2e566ec89c668edbd1bc958785b41f28c1cc02335ebd62c6` (`error: resource lease unavailable\n`). A positive-window held-lock check also returned `3` in `1054ms` for `wait=1` against a 1.2-second holder. An empty-lock acquire/release smoke test returned `0` with empty double streams and left no active/tmp/trash record.

Post-commit applicable gates all returned `0`: prototype `cmp -s`; line count `336`; `/tmp/aosp-harness-tools-04/shfmt -d -i 2 -ci -bn`; `/tmp/aosp-harness-tools-04/shellcheck -x --severity=warning`; `bash -n`; source-silent/public-surface/session-marker checks; and `git diff --check`. `BASE..HEAD` remains exactly one source path with numstat `336  0`; `git status --porcelain=v1` is 0B (clean).

## Fix round 2 — R7 post-deadline lock acquisition

- Fix BASE: `23ca68fe5e3c39a25d90d92b879e215045702a99`
- Fix HEAD / commit: `569bb221aca20451706b0a6399683a71255bd7d1` — `fix(harness): stop lease publish after deadline`
- Worktree change: `common/.harness/lib/resource-leases.sh` only (`2` insertions, `2` deletions); the approved prototype was synchronized byte-for-byte.

Fix2 RED used a live owner holding `.lock` for 1.2 seconds. A `wait=1` requester was stopped at 250ms and resumed after the deadline and lock release. Before repair it returned `0` after `1518ms`, emitted a 33-byte token, and left `active_count=1`; this confirms a publish after the missed deadline. Evidence: `evidence/task-1.1-fix2-red.txt`.

Fix2 GREEN repeated that stop/resume scenario after repair: it returned `3` after `1507ms`, stdout was 0B, stderr was exactly `error: resource lease unavailable\n`, and `active_count=0`. The no-contention `wait=0` acquire/release still returned `0` with empty double streams and zero active records. After the holder released, a subsequent normal acquire/release returned `0`, had empty double streams, and retained `active_count=0`.

Post-commit checks returned `0`: prototype `cmp -s`; exact `336` lines; fixed `/tmp/aosp-harness-tools-04/shfmt -d -i 2 -ci -bn`; fixed `/tmp/aosp-harness-tools-04/shellcheck -x --severity=warning`; `bash -n`; source/public-surface/session-marker validation; and `git diff --check 23ca68..HEAD`. The implementation worktree is clean.
