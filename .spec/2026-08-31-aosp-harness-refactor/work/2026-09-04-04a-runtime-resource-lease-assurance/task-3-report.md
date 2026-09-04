# Task 3 execution record

Execution BASE: `ffb05899c33d04b4c3d1c6605b3d39b1e6a05204`  
Accepted/candidate HEAD: `3f17cf66c1a13296d77ed1f900109fc1feb633c6`

The red precondition was recorded before this report existed: `test -s "$WORK/task-3-report.md"` returned rc `1`, with both streams empty. See [task-3-red.txt](evidence/task-3-red.txt).

Candidate verification ran in the supplied implementation worktree. Its initial and final HEAD were both `3f17cf66c1a13296d77ed1f900109fc1feb633c6`; both `git status --porcelain` results were empty. Fixed tools reported `v3.14.0` (shfmt) and ShellCheck `version: 0.11.0`. Fixed shfmt, ShellCheck, and `bash -n` each returned `0` with empty output. Both delivery files were byte-identical to the supplied read-only prototypes.

`git diff BASE ACCEPTED_HEAD` named exactly `common/.harness/lib/resource-leases.sh` and `tests/test-resource-leases-assurance.sh`; numstat was provider `2/2` and assurance `396/0`, for total churn `400` (`398` added plus `2` deleted). The provider hunk is exactly the deadline branch replacement; docs and the base lease test had empty diffs. `git diff --check` returned `0` and emitted nothing.

Candidate default assurance returned `0`, stdout exactly `RESULT PASS  resource lease assurance`, and empty stderr. Candidate offline returned `0`; its assurance summary occurred once and its final line was `RESULT PASS  aosp-harness offline quality gate`.

The complete candidate command/output record and delivery hashes are in [task-3-candidate-offline.log](evidence/task-3-candidate-offline.log) and [task-3-package.tsv](evidence/task-3-package.tsv). Delivery SHA-256 values were provider `fa6784af1824ae4dc79dca2af01b7edab3392f3e96b4d326a089273b1c228bac` and assurance `0bf21e8f9d29e5a87cdcc8e962ede20143ccbf49fcb742756923f519b327690b`.

For the complete-history case, `git clone --no-local "$IMPLEMENTATION_WORKTREE" full` was made under the repo-external temporary root `/tmp/aosp-task3-checkouts.2GbKJT`. Its HEAD equaled accepted HEAD. It repeated the exact two-file/`2/2` plus `396/0` diff, default assurance and offline all with rc `0`, one offline assurance discovery, empty `git diff --check`, and an empty status. See [task-3-full.log](evidence/task-3-full.log).

For the real shallow case, `git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE" depth1` was made beneath the same temporary root. Its HEAD equaled accepted HEAD, `git rev-list --count HEAD` was `1`, and `.git/shallow` was nonempty (41 bytes). No BASE object was queried in this clone: both delivery files were `cmp -s` identical to their read-only prototypes, and delivery blobs/SHA-256 plus docs/base-test SHA-256 matched candidate records. Default assurance and offline returned `0`, the assurance summary was found exactly once in offline output, and status was empty. See [task-3-depth1.log](evidence/task-3-depth1.log).

Rollback was isolated in the full clone on temporary branch `task3-rollback-3f17cf66`. The temporary commit `147052cfd2d4469b24f81602d19c564d9571c7c8` restored the provider from BASE and deleted the assurance entry; versus accepted HEAD its numstat was provider `2/2` and assurance `0/396`. The rollback source diff relative to BASE was empty, as was `UPSTREAM` relative to BASE. `tests/test-resource-leases.sh`, `tests/test-claude-session-lifecycle.sh`, and offline each returned `0`; offline found the assurance entry zero times, and the checkout was clean. See [task-3-rollback.log](evidence/task-3-rollback.log).

Cleanup used only the exact repo-external paths `/tmp/aosp-task3-checkouts.2GbKJT` and `/tmp/aosp-task3-candidate.5QPeyF`. Each was first verified to be an existing non-symlink directory with the exact expected prefix. The environment rejected `rm -f`-style deletion, so `gio trash` was used for those paths and the two temporary check-output files; every target was then verified physically absent. The temporary rollback branch was detached from and deleted before the tree cleanup. No implementation-branch commit was created; final implementation HEAD remained accepted HEAD and its status output remained empty.
