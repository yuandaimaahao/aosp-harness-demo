# 任务 2.1 报告: 审计candidate并固定accepted HEAD

## task

- 任务: task-2.1（spec 2026-09-02-03b-session-snapshot-safety，需求 R8）
- 范围: 只执行步骤 1–3（红证据 → candidate 审计 → green 报告与 evidence package）；步骤 4–5 由控制器执行
- 本任务不创建 commit、不改变 HEAD

## base

- execution BASE: `3d15a0d76c2a2e6c8541c5d47001a55f0ca18649`（execution-base.env 的 BASE_SHA）

## head

- HEAD: `ab1e870ece16bbc24e1a86f84110366f84aae0d9`（任务 1.2 head，审计前后不变）
- 工作树: clean（`git status --porcelain` 前后均 0 行）

## files

审计对象（`BASE..HEAD` exact 两文件，numstat 208+192=400 <= 400）:

- `common/.harness/lib/session-state-snapshot.sh`（新增 208 行）
- `tests/test-session-snapshot.sh`（新增 192 行）

验收资产（不纳入源码文件清单）:

- 创建 `evidence/task-2.1-red.txt`
- 创建 `task-2.1-report.md`（本文件）
- 创建 `evidence/task-2.1-evidence.tsv`
- `review-manifest.tsv` 由控制器在步骤 5 修改

## commands

红阶段证据: `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-2.1-red.txt`

步骤 1（红）:
- `test -s $WORK/task-2.1-report.md` → rc1，双流空（报告缺席，红成立）
- 前置: worktree HEAD = 任务 1.2 head 且 clean

步骤 2（candidate 审计，日志在 `evidence/task-2.1-logs/step2/`）:
- `sha256sum` 四上游文件 before/after 并 `cmp`（foundation/path/03a1-driver/03a2-entrypoint）
- 固定工具版本逐字核验: `shfmt --version` = `v3.14.0`；`shellcheck --version` 的 `version:` 字段 = `0.11.0`
- `shfmt -d -i 2 -ci -bn <exact两文件>`
- `shellcheck -x --severity=warning <exact两文件>`
- `bash -n` 两文件分别执行
- `bash ./tests/test-session-snapshot.sh`（default）
- `bash ./tests/test-session-snapshot.sh all`
- `bash ./scripts/check.sh --offline`，并核 stdout 中 `RESULT PASS  session snapshot safety` 恰好 1 次

步骤 3（收敛核验，日志在 `evidence/task-2.1-logs/step3/`）:
- `git diff --name-only $BASE $HEAD` → exact 两文件
- `git diff --numstat $BASE $HEAD` → 208+0 / 192+0，总和 400 <= 400
- `git diff --check $BASE $HEAD` → rc0，双流空
- 八 anchor 在 `session-state-snapshot.sh` 中各精确 1 次（grep -c）
- surface: source 三模块后 rc0/双流空；`_harness_session_snapshot_worker`、`_harness_session_snapshot_write_core`、`_harness_session_snapshot_read_core` 三个 export 存在；`harness_session_path/write/read/remove` 四个 public API 缺席；`HARNESS_SESSION_STATE_PROVIDER_VERSION` 在生产文本与环境中均 0 次
- `git status --porcelain` → clean

## results

全部通过，未发现源码缺陷，无需回流任务 1.1/1.2:

| 检查 | 结果 |
|---|---|
| 红: report 缺席 | rc1，双流空 ✓ |
| 前置: HEAD=任务1.2 head + clean | ✓ |
| shfmt 版本 | v3.14.0 ✓ |
| ShellCheck 版本字段 | 0.11.0 ✓ |
| shfmt -d -i 2 -ci -bn | rc0，无 diff ✓ |
| shellcheck -x --severity=warning | rc0，无诊断 ✓ |
| bash -n（两文件） | 均 rc0 ✓ |
| default | rc0，stdout 逐字 `RESULT PASS  session snapshot safety\n`，stderr 0B ✓ |
| all | rc0，同一固定摘要，stderr 0B ✓ |
| offline | rc0，末行 `RESULT PASS  aosp-harness offline quality gate`，snapshot 摘要恰 1 次，stderr 0B ✓ |
| 四上游 SHA-256 before/after | `cmp` 一致 ✓ |
| BASE..HEAD name-only | exact 两文件 ✓ |
| numstat 总和 | 400 <= 400 ✓ |
| git diff --check | rc0 ✓ |
| 八 anchor exact-once | 各 1 次 ✓ |
| source rc/双流 | rc0，双流 0B ✓ |
| 3 export / 4 public API / provider marker | 3 存在、4 缺席、marker 0 次 ✓ |
| worktree clean | ✓ |

测试摘要: candidate default/all/offline 全 PASS（offline 3 个 RESULT PASS 行，snapshot 摘要恰 1 次），静态工具全绿，BASE..HEAD 收敛核验全过。
