# Task 2 report: resource lease assurance

Status: PASS

- Base: `3ab44a5430d9038d20ec143ebe2c0846349f584e`
- Head: `3f17cf66c1a13296d77ed1f900109fc1feb633c6`
- Source file: `tests/test-resource-leases-assurance.sh` only; commit numstat `396/0`.
- Prototype: `/tmp/aosp-harness-publish-04-main.AGaEae/.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-04-04a-runtime-resource-lease-assurance/prototypes/tests/test-resource-leases-assurance.sh`; SHA-256 `0bf21e8f9d29e5a87cdcc8e962ede20143ccbf49fcb742756923f519b327690b`; 24,945 bytes; 396 lines.
- Mechanical-copy comparison: `cmp -s tests/test-resource-leases-assurance.sh "$prototype"` returned 0 before commit and at HEAD.

## Active matrix streams

| Command | rc | elapsed | stdout bytes / SHA-256 | stderr bytes / SHA-256 |
|---|---:|---:|---|---|
| `bash ./tests/test-resource-leases-assurance.sh` | 0 | 45 s | 38 / `0efda5495dd5fa42489228b3267f9adf88a97d038370adad9f9e17b386d30855` | 0 / `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `bash ./tests/test-resource-leases-assurance.sh all` | 0 | 43 s | 38 / `0efda5495dd5fa42489228b3267f9adf88a97d038370adad9f9e17b386d30855` | 0 / `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

Both captured stdout streams are byte-exact `RESULT PASS  resource lease assurance\\n`; both stderr streams are empty. Each run executes the prototype's full active matrix, including CLI and absent/damaged provider surfaces, request/root/state/record matrices, concurrency/barrier/waiting, PID stale reclaim, helper/output and I/O faults, adapter isolation, and four mutant oracles.

## Static and lifecycle evidence

Fixed tools passed: shfmt `v3.14.0` produced no diff; ShellCheck `0.11.0` with the warning threshold produced no output; and `bash -n` passed. The mechanically copied prototype has only ShellCheck info-level notices, recorded in the static evidence.

The default provider resolved to the repo-contained ordinary non-symlink file and retained exactly one seam. Provider, docs, and base-test hashes were unchanged during the active assurance runs. The temporary-tree property probe confirmed an external, EUID-owned, mode-0700 empty ordinary directory and its physical cleanup.

Lifecycle fault probes ran only from `/tmp/aosp-harness-task2-lifecycle.IzE9Z1`: fake `mktemp` returned rc 1 with empty stdout and `FAIL temporary tree fixture\\n`; fake `rm` returned rc 1 with empty stdout and `FAIL temporary tree cleanup\\n`; neither emitted the PASS summary. That fixture root remains solely for controller prefix verification and cleanup.

## Diff and cleanliness

`git diff-tree --no-commit-id --name-status -r HEAD` reports only `A tests/test-resource-leases-assurance.sh`; its numstat is `396/0`. Against execution base `ffb05899c33d04b4c3d1c6605b3d39b1e6a05204`, exactly two files changed: provider `2/2` and assurance `396/0`, for 400 total churn (`2 + 2 + 396`), with the provider hunk confined to the required adjacent deadline lines. Worktree status is clean.
