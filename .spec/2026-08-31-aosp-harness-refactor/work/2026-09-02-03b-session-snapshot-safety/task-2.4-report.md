# 任务 2.4 报告: 验证exact rollback

## task

- 任务: task-2.4（spec 2026-09-02-03b-session-snapshot-safety，需求 R9）
- 范围: 只执行步骤 1–4 的实现者部分（红证据 → 从 implementation clone rollback 到临时目录并核 HEAD=ACCEPTED_HEAD → `git rm` 两目标文件后提交普通 rollback commit 并核 name-status exact 两个 D → 在 rollback 中运行 03a path、03a1 self-test、03a2 race entrypoint 与 offline 并核全绿/snapshot 摘要 0 次/两目标物理缺席/clean → green 报告与 evidence package、删除 rollback checkout）；步骤 4 的独立 review/manifest 行追加与步骤 5 的 mark/ledger/sync 由控制器执行
- 本任务不在 implementation worktree 创建任何 commit、不改变其 HEAD；rollback commit 只存在于临时 clone 中

## base

- execution BASE: `3d15a0d76c2a2e6c8541c5d47001a55f0ca18649`（execution-base.env 的 BASE_SHA）

## head

- ACCEPTED_HEAD: `ab1e870ece16bbc24e1a86f84110366f84aae0d9`（任务 2.1 固定；implementation worktree 审计前后 HEAD 逐字等于该值且 clean）
- rollback clone HEAD（clone 后）: `ab1e870ece16bbc24e1a86f84110366f84aae0d9`（逐字等于 ACCEPTED_HEAD）
- rollback commit: `6c90230d8bcd06117db670c745c80442addf1831`，parent 逐字等于 ACCEPTED_HEAD；该 commit 只存在于已删除的临时 clone 中

## files

rollback commit 精确删除的两个文件（name-status 恰好两个 D）:

- `common/.harness/lib/session-state-snapshot.sh`
- `tests/test-session-snapshot.sh`

验收资产（不纳入源码文件清单）:

- 创建 `evidence/task-2.4-red.txt`
- 创建 `task-2.4-report.md`（本文件）
- 创建 `evidence/task-2.4-evidence.tsv`
- 创建 `evidence/task-2.4-logs/`（每次运行分离保存 rc/stdout/stderr）
- `review-manifest.tsv` 由控制器在独立 review PASS 后修改

## commands

红阶段证据: `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-2.4-red.txt`

步骤 1（红，日志在 `evidence/task-2.4-logs/red.*`）:
- `test -s $WORK/task-2.4-report.md` → rc1，双流空（报告缺席，红成立）
- 前置: implementation worktree HEAD = ACCEPTED_HEAD 且 `git status --porcelain` 0 行

步骤 2（rollback clone 与 rollback commit，日志 `clone.*` / `rollback-head.txt` / `git-rm.*` / `commit.*` / `name-status.txt` / `rollback-commit.txt` / `rollback-parent.txt`）:
- `tmp=$(mktemp -d /tmp/task-2.4-rollback.XXXXXX)`（/tmp/task-2.4-rollback.Af0fG7）
- `git clone --no-local "$IMPLEMENTATION_WORKTREE" "$tmp/rollback"` → rc0
- `git -C "$tmp/rollback" rev-parse HEAD` 逐字等于 ACCEPTED_HEAD
- `git rm common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh` → rc0
- `git commit -m "revert(session): remove snapshot module and test for rollback verification"` → rc0（普通 rollback commit，非 git revert 生成）
- `git diff-tree --no-commit-id --name-status -r HEAD` 逐字为两行 `D\tcommon/.harness/lib/session-state-snapshot.sh` 与 `D\ttests/test-session-snapshot.sh`（exact 两个 D，无其他条目）

步骤 3（在 rollback 中验证，日志 `path.*` / `selftest.*` / `races.*` / `offline.*` / `clean.txt`）:
- `bash tests/test-session-path.sh` → rc0、stderr 0B、stdout 末行 `RESULT PASS  session path safety`
- `python3 tests/lib/session-path-race-driver.py self-test common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh` → rc0、stderr 0B、stdout 末行 `RESULT PASS  session path race driver`
- `bash tests/test-session-path-races.sh` → rc0、stderr 0B、stdout 末行 `RESULT PASS  session path race assurance`
- `bash ./scripts/check.sh --offline` → rc0、stderr 0B、stdout 中 `RESULT PASS  session snapshot safety` 0 次（`session-snapshot` 零提及）、末行 `RESULT PASS  aosp-harness offline quality gate`
- `test ! -e` 两目标文件均物理缺席；`git status --porcelain` 0 行（clean）

步骤 4（本实现者部分）:
- 写本 green 报告与 `evidence/task-2.4-evidence.tsv`，删除 `$tmp`（含 rollback checkout）

## results

全部通过:

| 检查 | 结果 |
|---|---|
| 红: report 缺席 | rc1，双流空 ✓ |
| 前置: implementation HEAD=ACCEPTED_HEAD + clean | ✓ |
| clone --no-local | rc0 ✓ |
| rollback clone HEAD 逐字=ACCEPTED_HEAD | ✓ |
| `git rm` 两目标文件 | rc0 ✓ |
| 普通 rollback commit | rc0，parent=ACCEPTED_HEAD ✓ |
| name-status exact 两个 D | 恰好 `D snapshot.sh` + `D test-session-snapshot.sh` ✓ |
| `bash tests/test-session-path.sh` | rc0，`RESULT PASS  session path safety`，stderr 0B ✓ |
| race-driver self-test | rc0，`RESULT PASS  session path race driver`，stderr 0B ✓ |
| `bash tests/test-session-path-races.sh` | rc0，`RESULT PASS  session path race assurance`，stderr 0B ✓ |
| offline | rc0，snapshot 摘要 0 次，末行 `RESULT PASS  aosp-harness offline quality gate`，stderr 0B ✓ |
| 两目标文件物理缺席 | `test ! -e` 均成立 ✓ |
| rollback checkout clean | `git status --porcelain` 0 行 ✓ |
| rollback checkout 已删除 | ✓ |
| implementation worktree HEAD 不变 | 本任务未在 implementation worktree 创建 commit ✓ |

测试摘要: 隔离 rollback commit（exact 两个 D）的 clean checkout 中 03a path、03a1 self-test、03a2 race entrypoint 与 offline 全 rc0 全绿，offline 中 snapshot 摘要 0 次，两目标文件物理缺席，临时 checkout 已删除。
