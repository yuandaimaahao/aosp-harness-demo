DONE

parent: `5ab105e8909e893a055e6e834abceb9192e0b133`
commit: `806fb63b782c45c0aa98939024e5a0a143d6e1fc`
owned path: `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/modes/pre_commit.py`

Tests:

- Red phase: rc 1, empty stdout, exact `RESULT FAIL supersession CAPABILITY_UNAVAILABLE`; evidence: `task-2-red.txt`.
- Current task worktree subset gate: rc 0, exact `RESULT PASS environment-seed-preflight-supersession-pre-commit`, empty stderr.
- Temporary Git fixtures: base mismatch → `BASE_HEAD_MISMATCH`; extra path and merge history → `COMMIT_SCOPE_MISMATCH`; tracked and untracked `common/` → `COMMON_SCOPE_VIOLATION`; legal subset → exact PASS. All failure fixtures had rc 1 and empty stdout.
- Commit checks: task-parent path set exactly the owned path; whitespace check passed.

红阶段证据: `.spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/task-2-red.txt`

Cumulative base-relative numstat (`7b46dfba287f2e3e3fb9ca00c3186b69c4720dc7..806fb63b782c45c0aa98939024e5a0a143d6e1fc`): 435 additions, 0 deletions, 435 total (<=800).
