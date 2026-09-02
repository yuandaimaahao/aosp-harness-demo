# 任务 2.6 报告：收敛 manifest、ledger 与终交付（步骤 1–2）

## task

- task-2.6：红阶段（acceptance 报告缺席）+ 汇总 candidate/full/depth-1/rollback/order 既有日志与报告到 acceptance 报告与本 green 报告，生成 evidence package；本执行只做步骤 1–2，manifest 追加、awk 核验、mark、ledger 与终门重跑（步骤 3–6）由控制器在独立 review PASS 后执行。零 delta——本任务不产生任何 commit，implementation worktree 与主仓库 HEAD 不变。
- 红阶段证据:
.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/evidence/task-2.6-red.txt
  - 红阶段记录内容：`test -s "$WORK/acceptance/acceptance-report.md"` 在报告缺席时 rc=1，双流为空。

## base

- ACCEPTED_HEAD = `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`（任务 2.1 固定；execution BASE 为 `8a164f212c398a95703a38fb919af2b31c6e1662`，见 `WORK/execution-base.env`）。

## head

- implementation HEAD = `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`（`impl-head.txt`），验证前后不变且 clean（`impl-status.log` 0 字节）。
- 零 delta 成立：本任务只写验收资产（acceptance 报告、本报告、red 文件与 evidence package），implementation worktree 与主仓库零提交。

## files

- 验证对象：`tests/test-session-snapshot-assurance.sh`（终交付，锚点 `session-snapshot-assurance-v1` 已记入 acceptance 报告）。
- 本任务产出（验收资产，不纳入源码）：
  - `acceptance/acceptance-report.md`（验收报告：accepted HEAD、active 摘要逐字、八 anchor 注入点、`ASSURANCE_UNLINK_LOG` ENOENT oracle、exact1/400（实际 346）、241 断言口径（prototype 240 + UNLINK_LOG oracle 1）、candidate/full/depth-1/rollback/order 既有证据汇总）
  - `task-2.6-report.md`（本报告）
  - `evidence/task-2.6-red.txt`（红阶段证据，六行 schema + assertion）
  - `evidence/task-2.6-logs/`（红阶段与基线核对日志）
  - `evidence/task-2.6-evidence.tsv`（三列 evidence 清单，含 acceptance-report.md）

## commands

1. 红阶段：`test -s "$WORK/acceptance/acceptance-report.md"` → rc=1（报告缺席），双流 0 字节（`red.stdout`/`red.stderr`）；写 red 文件并核 `test -s "$WORK/evidence/task-2.6-red.txt"` 通过。
2. 基线核对：`git -C "$WORK/worktree" rev-parse HEAD` 逐字等于 ACCEPTED_HEAD（`impl-head.txt`）；`git status --porcelain` 0 字节（`impl-status.log`）。
3. 汇总写盘：依据 `task-1.1-report.md`、`task-2.1-report.md`…`task-2.5-report.md` 及各自 `evidence/task-*-logs/` 与 review 报告，写 `acceptance/acceptance-report.md`（只引用路径 + 关键实测值，不复制大段日志正文），再写本报告。
4. evidence package：对 brief、acceptance 报告、本报告、red 文件与全部日志生成三列 TSV `evidence/task-2.6-evidence.tsv`（path/sha256/bytes）。

## results

- 红阶段：rc=1、双流为空（acceptance 报告缺席，先于写盘记录）—— 成立。
- acceptance 报告已含全部必备要素：accepted HEAD `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`、active 摘要 `RESULT PASS  session snapshot assurance`（逐字）、八 anchor 注入点、`ASSURANCE_UNLINK_LOG` ENOENT oracle、exact1/400（实际 346）、241 断言口径，以及 candidate（2.1）/full（2.2）/depth-1（2.3）/rollback（2.4）/order（2.5）的既有日志与报告要点 —— PASS。
- implementation HEAD 不变且 clean；本任务零 commit —— 零 delta 成立。
- 本执行不含步骤 3–6：manifest 第 7 行追加、awk 七行核验、mark 2.6、ledger 完成锚点与终门重跑均由控制器在独立 review PASS 后执行。
