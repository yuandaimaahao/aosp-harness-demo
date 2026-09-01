# Task 4 v5.5 review fix 1

Worktree: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a-session-path-safety`

Expected HEAD: `3fd9053d504a2bf48f59e450099ccdabeaf6b22d`

Review: main repo work directory `task-4-v5.5-review-round1.md`.

Fix the blocker and minor only:

1. Remove the long-term test's hard-coded execution BASE SHA/foundation historical diff. BASE..HEAD foundation immutability remains a controller acceptance command in requirements/tasks and must not require an old Git object in the automatically discovered runtime test.
2. Clean the ignored first `invoke` argument and its callers if this reduces ambiguity without weakening any oracle.
3. Add/run a real depth-1 shallow-clone regression: clone a repository containing final candidate HEAD with `--depth 1` through a local file URL, then run `bash ./tests/test-session-path.sh` and `bash ./scripts/check.sh --offline`; both must rc0, path stdout exact 33-byte PASS/stderr empty, gate final PASS. Do not modify CI workflow or add a third implementation file.
4. Re-run all task4 v5.5 exact-stream/inert/self-disproof gates, foundation/offline, fixed shfmt/ShellCheck, syntax/diff-check, exact2/400 and clean status. Provider must remain unchanged. Expected line count should remain <=392.

Commit with personal Conventional Commit, e.g. `fix(session): support shallow quality checkouts`. Write `task-4-v5.5-fix1-report.md` to the main work directory. If blocked, restore clean at starting HEAD and report BLOCKED.
