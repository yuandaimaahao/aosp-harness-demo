# Task 4 v5.5 implementation brief

Worktree: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a-session-path-safety`

Expected base: `fad7bf384d9d8807f1f268649bc8ed19e10cf4b0`

Authoritative spec:

- main repo `.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-01-03a-session-path-safety/{requirements.md,design.md,tasks.md,sizing-prototype.md}`
- executable shape: main repo `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03a-session-path-safety/v5.5-round2-test-session-path.prototype.sh`
- sizing evidence: sibling `v5.5-round2-sizing-report.md`

Implement only task4 final correction in the isolated worktree. Do not modify foundation or `.spec` in the implementation worktree.

Required changes:

1. Remove `--case mutations`, its default child, and its complete anchor-replacement/provider-copy body. Retain source-validate, roots-static, deterministic non-anchor post-mkdir disappearance classification probe, 2×2/static attacks, and all existing production provider behavior.
2. Structure oracle must count three anchors globally and extract lexical `open_managed` body, proving each of before_mkdir/after_eexist/before_open occurs once globally and once inside that body. Retain no-fchmod check.
3. Only provider is globally mandatory. With foundation present, default runs source-validate then roots-static. In a real repository copy that retains provider/test but physically removes foundation, default and `--dependency-absent` both run the real all-missing inert oracle and return exact summary.
4. Compare every child/default summary using files/`cmp`, preserving the final LF; exact stdout is `RESULT PASS  session path safety\n`, stderr empty, rc0. Remove unused locals and resolve ShellCheck warnings.
5. Use fixed binaries `/tmp/aosp-gate-review.T8RDQ1/shellcheck/shellcheck` and `/tmp/aosp-gate-review.T8RDQ1/shfmt`; first assert versions 0.11.0/v3.14.0, apply shfmt `-w -i 2 -ci -bn`, then require ShellCheck `-x --severity=warning` and shfmt `-d -i 2 -ci -bn` on both implementation files.
6. Run default, source-validate, roots-static, explicit dependency-absent, real-foundation-file-absent default/flag, foundation regression, offline gate, syntax, diff-check. Verify BASE `d68911bde93f72d1e42dc85fba6271159e945170` to final candidate is exact two owned files and numstat <=400. Expected sizing shape is 392/400 with only 8 lines margin; do not add new cases.

Commit with a personal-project Conventional Commit, preferably `test(session): fit path contract within quality gate`. Write a report in the main repo work directory named `task-4-v5.5-report.md` with commit SHA, exact tests/streams, tool versions, numstat, worktree status and concerns. If any hard gate cannot pass, restore the implementation worktree clean at the starting HEAD and report BLOCKED without committing.
